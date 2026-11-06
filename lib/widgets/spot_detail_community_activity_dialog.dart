import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_training_plan.dart';
import '../models/spot_training_stats.dart';
import '../services/spot_check_in_service.dart';
import '../services/spot_training_plan_service.dart';
import '../services/spot_training_stats_service.dart';
import '../utils/community_activity_share.dart';
import '../utils/community_activity_time_formatting.dart';
import 'spot_check_in_presence.dart';
import 'training_plan_presence.dart';

enum _CommunityDialogSection { hereNow, planning, recentlyTrained }

Widget _communityActivitySectionHeader({
  required ThemeData theme,
  required AppLocalizations l10n,
  required _CommunityDialogSection section,
}) {
  final scheme = theme.colorScheme;
  final IconData icon;
  final Color color;
  final String title;
  switch (section) {
    case _CommunityDialogSection.hereNow:
      icon = Icons.place_outlined;
      color = scheme.primary;
      title = l10n.spotDetailPresenceHereNow;
    case _CommunityDialogSection.planning:
      icon = Icons.event_available_outlined;
      color = scheme.secondary;
      title = l10n.spotDetailCommunityPlanningToTrain;
    case _CommunityDialogSection.recentlyTrained:
      icon = Icons.history;
      color = scheme.primary;
      title = l10n.spotDetailCommunityRecentlyTrained;
  }
  return Semantics(
    header: true,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Single dialog: live check-ins, planned sessions, and recent public trainers.
void showSpotCommunityActivityDialog(
  BuildContext context,
  ThemeData theme,
  String spotId, {
  String? spotDisplayName,
  String? countryCode,
  String? city,
  Future<void> Function(SpotTrainingPlan sourcePlan)? onJoinTrainingPlan,
  VoidCallback? onLoginRequired,
}) {
  final hostContext = context;
  final shareContext = CommunitySpotShareContext(
    spotId: spotId,
    spotDisplayName: spotDisplayName,
    countryCode: countryCode,
    city: city,
  );
  final checkSvc = Provider.of<SpotCheckInService>(context, listen: false);
  final planSvc = Provider.of<SpotTrainingPlanService>(context, listen: false);
  final statsSvc =
      Provider.of<SpotTrainingStatsService>(context, listen: false);
  final checkStream = watchCheckInAvatarEntriesForSpot(checkSvc, spotId);
  final planStream = watchTrainingPlanAvatarEntriesForSpot(planSvc, spotId);
  final statsStream = statsSvc.watchStats(spotId);
  final l10n = AppLocalizations.of(context)!;

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Icon(
              Icons.groups_2_outlined,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.spotDetailCommunitySectionTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(420, maxH),
          child: StreamBuilder<List<CheckInAvatarEntry>>(
            stream: checkStream,
            builder: (context, checkSnap) {
              return StreamBuilder<List<TrainingPlanAvatarEntry>>(
                stream: planStream,
                builder: (context, planSnap) {
                  return StreamBuilder<SpotTrainingStats>(
                    stream: statsStream,
                    builder: (context, statsSnap) {
                      if (checkSnap.hasError ||
                          planSnap.hasError ||
                          statsSnap.hasError) {
                        return Center(
                          child: Text(
                            l10n.spotDetailCommunityActivityLoadError,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        );
                      }
                      if (!checkSnap.hasData ||
                          !planSnap.hasData ||
                          (!statsSnap.hasData &&
                              statsSnap.connectionState ==
                                  ConnectionState.waiting)) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final checkEntries = List<CheckInAvatarEntry>.from(
                        checkSnap.data!,
                      )..sort(
                          (a, b) => b.checkIn.checkedInAt.compareTo(
                            a.checkIn.checkedInAt,
                          ),
                        );
                      final planEntries = List<TrainingPlanAvatarEntry>.from(
                        planSnap.data!,
                      )..sort(
                          (a, b) => b.plan.plannedStartAt.compareTo(
                            a.plan.plannedStartAt,
                          ),
                        );
                      final recentPeople =
                          (statsSnap.data ?? SpotTrainingStats.empty)
                              .recentPeople;

                      if (checkEntries.isEmpty &&
                          planEntries.isEmpty &&
                          recentPeople.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.spotDetailCommunityActivityEmpty,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        );
                      }

                      final dialogTheme = Theme.of(context);
                      final children = <Widget>[];

                      void addSectionGap() {
                        if (children.isNotEmpty) {
                          children.add(const SizedBox(height: 20));
                        }
                      }

                      if (checkEntries.isNotEmpty) {
                        addSectionGap();
                        children.add(
                          _communityActivitySectionHeader(
                            theme: dialogTheme,
                            l10n: l10n,
                            section: _CommunityDialogSection.hereNow,
                          ),
                        );
                        children.add(const SizedBox(height: 10));
                        for (var i = 0; i < checkEntries.length; i++) {
                          if (i > 0) children.add(const SizedBox(height: 10));
                          children.add(
                            CheckInUserCard(
                              key: ValueKey('c-${checkEntries[i].checkIn.id}'),
                              entry: checkEntries[i],
                              hostContext: hostContext,
                              shareContext: shareContext,
                            ),
                          );
                        }
                      }

                      if (planEntries.isNotEmpty) {
                        addSectionGap();
                        children.add(
                          _communityActivitySectionHeader(
                            theme: dialogTheme,
                            l10n: l10n,
                            section: _CommunityDialogSection.planning,
                          ),
                        );
                        children.add(const SizedBox(height: 10));
                        for (var i = 0; i < planEntries.length; i++) {
                          if (i > 0) children.add(const SizedBox(height: 10));
                          children.add(
                            TrainingPlanUserCard(
                              key: ValueKey('p-${planEntries[i].plan.id}'),
                              entry: planEntries[i],
                              hostContext: hostContext,
                              shareContext: shareContext,
                              onJoinTrainingPlan: onJoinTrainingPlan,
                              onLoginRequired: onLoginRequired,
                            ),
                          );
                        }
                      }

                      if (recentPeople.isNotEmpty) {
                        addSectionGap();
                        children.add(
                          _communityActivitySectionHeader(
                            theme: dialogTheme,
                            l10n: l10n,
                            section: _CommunityDialogSection.recentlyTrained,
                          ),
                        );
                        children.add(const SizedBox(height: 10));
                        for (var i = 0; i < recentPeople.length; i++) {
                          if (i > 0) children.add(const SizedBox(height: 10));
                          children.add(
                            _RecentTrainerCard(
                              key: ValueKey('r-${recentPeople[i].userId}'),
                              trainer: recentPeople[i],
                              hostContext: hostContext,
                            ),
                          );
                        }
                      }

                      return ListView(
                        padding: EdgeInsets.zero,
                        children: children,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.spotTrainingPlanListDialogClose),
          ),
        ],
      );
    },
  );
}

class _RecentTrainerCard extends StatelessWidget {
  const _RecentTrainerCard({
    super.key,
    required this.trainer,
    required this.hostContext,
  });

  final SpotRecentTrainer trainer;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = trainer.displayName?.trim();
    final title = (name != null && name.isNotEmpty)
        ? name
        : l10n.spotCheckInUnnamedPerson;
    final when = communityStreamRelativeTime(trainer.lastCheckedInAt, l10n);
    final photo = trainer.photoURL?.trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop();
          await navigateToUserProfileForCheckIn(hostContext, trainer.userId);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                backgroundImage: (photo != null && photo.isNotEmpty)
                    ? NetworkImage(photo)
                    : null,
                child: (photo != null && photo.isNotEmpty)
                    ? null
                    : Text(
                        title.substring(0, 1).toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.spotDetailCommunityRecentLastTrained(when),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
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
