import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';

/// Pure validation for planned training windows (client + unit tests).
abstract final class SpotTrainingPlanValidation {
  /// `null` if valid; otherwise a stable code for localization.
  static String? validateWindow({
    required DateTime plannedStartAt,
    required DateTime plannedEndAt,
    required DateTime now,
    required bool requireEndInFuture,
  }) {
    final start = plannedStartAt.toUtc();
    final end = plannedEndAt.toUtc();
    final nowUtc = now.toUtc();
    if (!end.isAfter(start)) {
      return 'order';
    }
    final dur = end.difference(start);
    if (dur < SpotTrainingPlan.minWindowDuration) {
      return 'minDuration';
    }
    if (dur > SpotCheckIn.maxSessionDuration) {
      return 'maxDuration';
    }
    final latestStart = nowUtc.add(SpotTrainingPlan.maxAdvanceHorizon);
    if (start.isAfter(latestStart)) {
      return 'startTooFar';
    }
    if (requireEndInFuture && !end.isAfter(nowUtc)) {
      return 'endNotFuture';
    }
    return null;
  }
}
