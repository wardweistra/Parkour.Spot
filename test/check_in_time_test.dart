import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';
import 'package:parkour_spot/utils/check_in_time.dart';

void main() {
  group('defaultExpectedEndAt', () {
    test('floors one hour later to nearest quarter hour', () {
      final from = DateTime(2025, 3, 27, 10, 7, 30);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 11, 0));
    });

    test('10:53 start yields 11:45 after floor', () {
      final from = DateTime(2025, 3, 27, 10, 53);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 11, 45));
    });

    test('on exact quarter boundary stays on boundary', () {
      final from = DateTime(2025, 3, 27, 9, 0);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 10, 0));
    });
  });

  group('trainingPlanEligibleForLinkedCheckIn', () {
    SpotTrainingPlan planEnding(DateTime end) {
      return SpotTrainingPlan(
        id: 'p1',
        userId: 'u1',
        spotId: 's1',
        plannedStartAt: end.subtract(const Duration(hours: 1)),
        plannedEndAt: end,
        isPrivate: false,
      );
    }

    test('true when planned end is after now but within 12h', () {
      final now = DateTime(2025, 6, 1, 10, 0);
      final end = now.add(const Duration(hours: 3));
      expect(trainingPlanEligibleForLinkedCheckIn(planEnding(end), now), isTrue);
    });

    test('false when planned end is in the past', () {
      final now = DateTime(2025, 6, 1, 10, 0);
      final end = now.subtract(const Duration(minutes: 1));
      expect(trainingPlanEligibleForLinkedCheckIn(planEnding(end), now), isFalse);
    });

    test('false when planned end is more than 12h away', () {
      final now = DateTime(2025, 6, 1, 10, 0);
      final end = now.add(const Duration(hours: 13));
      expect(trainingPlanEligibleForLinkedCheckIn(planEnding(end), now), isFalse);
    });
  });
}
