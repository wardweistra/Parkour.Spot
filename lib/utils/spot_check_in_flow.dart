import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_check_in.dart';
import '../models/spot_training_plan.dart';
import '../services/spot_check_in_service.dart';
import '../services/spot_training_plan_service.dart';
import '../utils/check_in_time.dart';
import '../widgets/spot_check_in_dialog.dart';

/// Fetches parallel data, shows the check-in dialog, ends other active sessions, then [SpotCheckInService.checkIn].
///
/// When [fixedTrainingPlan] is set (e.g. user chose “Check in” from Edit plan), it is used for plan linking
/// instead of re-fetching the active plan at the spot.
Future<void> runSpotCheckInFlow(
  BuildContext context, {
  required AppLocalizations l10n,
  required String spotId,
  required String spotName,
  SpotTrainingPlan? fixedTrainingPlan,
  required Future<void> Function(SpotCheckIn checkIn) onExtendInsteadEdit,
  required void Function(String message) showSuccess,
  required void Function(String message) showError,
  required String successMessage,
}) async {
  final checkInSvc = Provider.of<SpotCheckInService>(context, listen: false);
  final planSvc = Provider.of<SpotTrainingPlanService>(context, listen: false);

  final futures = <Future<Object?>>[
    checkInSvc.fetchActiveCheckInsElsewhere(spotId),
    checkInSvc.fetchExtendableCheckInAtSpot(spotId),
  ];
  if (fixedTrainingPlan == null) {
    futures.add(planSvc.fetchMyActivePlanAtSpot(spotId));
  }
  final results = await Future.wait<Object?>(futures);
  if (!context.mounted) return;

  final activeElsewhere = results[0] as List<SpotCheckIn>?;
  final extendableAtSameSpot = results[1] as SpotCheckIn?;
  final planForLink = fixedTrainingPlan ??
      (results.length > 2 ? results[2] as SpotTrainingPlan? : null);

  if (activeElsewhere == null) {
    showError(checkInSvc.error ?? l10n.spotDetailCheckInVerifyFailed);
    return;
  }

  final linked = planForLink != null &&
          trainingPlanEligibleForLinkedCheckIn(planForLink, DateTime.now())
      ? planForLink
      : null;

  final result = await showSpotCheckInDialog(
    context,
    activeElsewhere: activeElsewhere,
    extendableAtSameSpot: extendableAtSameSpot,
    linkedTrainingPlan: linked,
  );
  if (!context.mounted) return;
  if (result == null) return;
  if (result is SpotCheckInDialogExtendInstead) {
    await onExtendInsteadEdit(result.checkIn);
    return;
  }
  if (result is! SpotCheckInDialogSaved) return;

  for (final other in activeElsewhere) {
    final ended = await checkInSvc.endCheckInNow(other);
    if (!context.mounted) return;
    if (!ended) {
      showError(checkInSvc.error ?? l10n.spotDetailCheckInEndPreviousFailed);
      return;
    }
  }

  final ok = await checkInSvc.checkIn(
    spotId,
    isPrivate: result.isPrivate,
    expectedEndAt: result.expectedEndAt,
    comment: result.comment,
    spotName: spotName,
    consumeTrainingPlanId: result.consumeTrainingPlanId,
  );
  if (!context.mounted) return;
  if (ok) {
    showSuccess(successMessage);
  } else {
    showError(checkInSvc.error ?? l10n.spotDetailCheckInFailed);
  }
}
