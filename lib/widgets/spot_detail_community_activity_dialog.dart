import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_training_plan.dart';
import '../services/spot_check_in_service.dart';
import '../services/spot_training_plan_service.dart';
import '../utils/community_activity_share.dart';
import 'spot_check_in_presence.dart';
import 'training_plan_presence.dart';

Widget _communityActivitySectionHeader({
  required ThemeData theme,
  required AppLocalizations l10n,
  required bool hereNow,
}) {
  final scheme = theme.colorScheme;
  final color = hereNow ? scheme.primary : scheme.secondary;
  return Semantics(
    header: true,
    child: Row(
      children: [
        Icon(
          hereNow ? Icons.place_outlined : Icons.event_available_outlined,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hereNow
                ? l10n.spotDetailPresenceHereNow
                : l10n.spotDetailCommunityPlanningToTrain,
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

/// Single dialog: check-ins and training plans in **one** scrollable list (no duplicate strips).
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
  final checkStream = watchCheckInAvatarEntriesForSpot(checkSvc, spotId);
  final planStream = watchTrainingPlanAvatarEntriesForSpot(planSvc, spotId);
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
                  if (checkSnap.hasError || planSnap.hasError) {
                    return Center(
                      child: Text(
                        l10n.spotDetailCommunityActivityLoadError,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (!checkSnap.hasData || !planSnap.hasData) {
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

                  if (checkEntries.isEmpty && planEntries.isEmpty) {
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
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (checkEntries.isNotEmpty) ...[
                        _communityActivitySectionHeader(
                          theme: dialogTheme,
                          l10n: l10n,
                          hereNow: true,
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < checkEntries.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          CheckInUserCard(
                            key: ValueKey('c-${checkEntries[i].checkIn.id}'),
                            entry: checkEntries[i],
                            hostContext: hostContext,
                            shareContext: shareContext,
                          ),
                        ],
                      ],
                      if (checkEntries.isNotEmpty && planEntries.isNotEmpty)
                        const SizedBox(height: 20),
                      if (planEntries.isNotEmpty) ...[
                        _communityActivitySectionHeader(
                          theme: dialogTheme,
                          l10n: l10n,
                          hereNow: false,
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < planEntries.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          TrainingPlanUserCard(
                            key: ValueKey('p-${planEntries[i].plan.id}'),
                            entry: planEntries[i],
                            hostContext: hostContext,
                            shareContext: shareContext,
                            onJoinTrainingPlan: onJoinTrainingPlan,
                            onLoginRequired: onLoginRequired,
                          ),
                        ],
                      ],
                    ],
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
