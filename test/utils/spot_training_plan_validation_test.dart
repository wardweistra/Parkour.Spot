import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';
import 'package:parkour_spot/utils/spot_training_plan_validation.dart';

void main() {
  group('SpotTrainingPlanValidation', () {
    final now = DateTime.utc(2026, 6, 15, 12);

    test('accepts valid 1h window starting soon', () {
      final start = now.add(const Duration(minutes: 30));
      final end = start.add(const Duration(hours: 1));
      expect(
        SpotTrainingPlanValidation.validateWindow(
          plannedStartAt: start,
          plannedEndAt: end,
          now: now,
          requireEndInFuture: true,
        ),
        isNull,
      );
    });

    test('rejects window shorter than 15 minutes', () {
      final start = now.add(const Duration(minutes: 30));
      final end = start.add(const Duration(minutes: 10));
      expect(
        SpotTrainingPlanValidation.validateWindow(
          plannedStartAt: start,
          plannedEndAt: end,
          now: now,
          requireEndInFuture: true,
        ),
        'minDuration',
      );
    });

    test('rejects window longer than 12 hours', () {
      final start = now.add(const Duration(minutes: 30));
      final end = start.add(SpotCheckIn.maxSessionDuration + const Duration(minutes: 1));
      expect(
        SpotTrainingPlanValidation.validateWindow(
          plannedStartAt: start,
          plannedEndAt: end,
          now: now,
          requireEndInFuture: true,
        ),
        'maxDuration',
      );
    });

    test('rejects start more than 30 days out', () {
      final start = now.add(SpotTrainingPlan.maxAdvanceHorizon + const Duration(days: 1));
      final end = start.add(const Duration(hours: 1));
      expect(
        SpotTrainingPlanValidation.validateWindow(
          plannedStartAt: start,
          plannedEndAt: end,
          now: now,
          requireEndInFuture: true,
        ),
        'startTooFar',
      );
    });
  });
}
