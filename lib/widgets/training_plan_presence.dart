import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_check_in.dart';
import '../models/spot_training_plan.dart';
import '../services/auth_service.dart';
import '../services/spot_check_in_service.dart';
import '../services/spot_training_plan_service.dart';
import '../utils/community_activity_time_formatting.dart';
import '../utils/spot_check_in_flow.dart';
import '../widgets/spot_check_in_presence.dart';
import 'spot_check_in_dialog.dart';
import 'spot_training_plan_dialog.dart';

Future<void> _editCheckInAfterExtendFromPlanCard(
  BuildContext context,
  SpotCheckIn c,
) async {
  final svc = Provider.of<SpotCheckInService>(context, listen: false);
  final l10n = AppLocalizations.of(context)!;
  final stillHereEligible = await svc.stillHereEligibleForUser(c);
  if (!context.mounted) return;
  final result = await showSpotCheckInDialog(
    context,
    existingCheckIn: c,
    stillHereEligible: stillHereEligible,
  );
  if (result == null || !context.mounted) return;
  if (result is SpotCheckInDialogDeleted) {
    final deleted = await svc.deleteCheckIn(c.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? l10n.spotDetailCheckInRemoved
              : (svc.error ?? l10n.spotDetailCheckInDeleteFailed),
        ),
      ),
    );
    return;
  }
  if (result is! SpotCheckInDialogSaved) return;
  final ok = await svc.updateCheckIn(
    c.id,
    checkedInAt: result.checkedInAt!,
    isPrivate: result.isPrivate,
    expectedEndAt: result.expectedEndAt,
    comment: result.comment,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? l10n.spotDetailCheckInUpdated
            : (svc.error ?? l10n.spotDetailCheckInUpdateFailed),
      ),
    ),
  );
}

class TrainingPlanAvatarEntry {
  const TrainingPlanAvatarEntry(
    this.plan, {
    this.showPrivateBadge = false,
  });

  final SpotTrainingPlan plan;
  final bool showPrivateBadge;
}

List<TrainingPlanAvatarEntry> buildTrainingPlanAvatarEntries(
  List<SpotTrainingPlan> public,
  SpotTrainingPlan? mine,
) {
  final entries = public
      .map((p) => TrainingPlanAvatarEntry(p))
      .toList();
  if (mine != null && mine.isPrivate) {
    final already = public.any((p) => p.userId == mine.userId);
    if (!already) {
      entries.add(TrainingPlanAvatarEntry(mine, showPrivateBadge: true));
    }
  }
  return entries;
}

Stream<List<TrainingPlanAvatarEntry>> watchTrainingPlanAvatarEntriesForSpot(
  SpotTrainingPlanService svc,
  String spotId,
) {
  return Stream<List<TrainingPlanAvatarEntry>>.multi((controller) {
    List<SpotTrainingPlan> latestPublic = [];
    SpotTrainingPlan? latestMine;

    void emit() {
      controller.add(buildTrainingPlanAvatarEntries(latestPublic, latestMine));
    }

    late final StreamSubscription<List<SpotTrainingPlan>> sub1;
    late final StreamSubscription<SpotTrainingPlan?> sub2;
    sub1 = svc.watchPublicPlansForSpot(spotId).listen(
      (p) {
        latestPublic = p;
        emit();
      },
      onError: controller.addError,
    );
    sub2 = svc.watchMyPlanForSpot(spotId).listen(
      (m) {
        latestMine = m;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };
  });
}

class TrainingPlanUserCard extends StatelessWidget {
  const TrainingPlanUserCard({
    super.key,
    required this.entry,
    required this.hostContext,
  });

  final TrainingPlanAvatarEntry entry;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = entry.plan;
    final uid = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final isMine = uid != null && uid == p.userId;
    final name = p.displayName?.trim();
    final title = (name != null && name.isNotEmpty) ? name : l10n.spotTrainingPlanUnnamedPerson;
    final range = communityFriendlyTrainingWindow(
      p.plannedStartAt,
      p.plannedEndAt,
      l10n,
    );
    final comment = p.comment?.trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final userId = p.userId;
          Navigator.of(context).pop();
          await navigateToUserProfileForCheckIn(hostContext, userId);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrainingPlanDialogAvatar(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isMine)
                          IconButton(
                            tooltip: l10n.spotTrainingPlanEditMine,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () async {
                              final svc = Provider.of<SpotTrainingPlanService>(
                                context,
                                listen: false,
                              );
                              Navigator.of(context).pop();
                              final result = await showSpotTrainingPlanDialog(
                                hostContext,
                                existingPlan: p,
                              );
                              if (result == null || !hostContext.mounted) {
                                return;
                              }
                              if (result is SpotTrainingPlanDialogOpenCheckIn) {
                                final plan = result.plan;
                                await runSpotCheckInFlow(
                                  hostContext,
                                  l10n: AppLocalizations.of(hostContext)!,
                                  spotId: plan.spotId,
                                  spotName: plan.spotName ?? '',
                                  fixedTrainingPlan: plan,
                                  onExtendInsteadEdit: (c) =>
                                      _editCheckInAfterExtendFromPlanCard(
                                        hostContext,
                                        c,
                                      ),
                                  showSuccess: (m) => ScaffoldMessenger.of(
                                    hostContext,
                                  ).showSnackBar(
                                    SnackBar(content: Text(m)),
                                  ),
                                  showError: (m) => ScaffoldMessenger.of(
                                    hostContext,
                                  ).showSnackBar(
                                    SnackBar(content: Text(m)),
                                  ),
                                  successMessage:
                                      AppLocalizations.of(hostContext)!
                                          .spotDetailCheckInSuccess,
                                );
                                return;
                              }
                              if (result is SpotTrainingPlanDialogDeleted) {
                                final ok = await svc.deletePlan(p.id);
                                if (!hostContext.mounted) return;
                                if (ok) {
                                  ScaffoldMessenger.of(hostContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(hostContext)!
                                            .spotDetailTrainingPlanRemoved,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(hostContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        svc.error ??
                                            AppLocalizations.of(hostContext)!
                                                .spotDetailTrainingPlanDeleteFailed,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              if (result is! SpotTrainingPlanDialogSaved) {
                                return;
                              }
                              final ok = await svc.upsertPlan(
                                spotId: p.spotId,
                                plannedStartAt: result.plannedStartAt,
                                plannedEndAt: result.plannedEndAt,
                                isPrivate: result.isPrivate,
                                comment: result.comment,
                                spotName: p.spotName,
                              );
                              if (!hostContext.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(hostContext)!
                                          .spotDetailTrainingPlanUpdated,
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      svc.error ??
                                          AppLocalizations.of(hostContext)!
                                              .spotDetailTrainingPlanFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        if (entry.showPrivateBadge) ...[
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.spotTrainingPlanOnlyYou,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      range,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '💬 $comment',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingPlanDialogAvatar extends StatelessWidget {
  const TrainingPlanDialogAvatar({super.key, required this.entry});

  final TrainingPlanAvatarEntry entry;

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = entry.plan;
    final avatar = CircleAvatar(
      radius: _radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: p.photoURL != null ? NetworkImage(p.photoURL!) : null,
      child: p.photoURL == null
          ? Text(
              (p.displayName?.isNotEmpty == true ? p.displayName![0] : '?')
                  .toUpperCase(),
              style: theme.textTheme.titleSmall,
            )
          : null,
    );

    if (!entry.showPrivateBadge) {
      return avatar;
    }

    return SizedBox(
      width: _radius * 2,
      height: _radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 1,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.lock_outline,
                  size: _radius * 0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
