import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_training_stats.dart';

void main() {
  group('SpotTrainingStats.fromMap', () {
    test('empty map yields empty stats', () {
      expect(SpotTrainingStats.fromMap(null), SpotTrainingStats.empty);
      expect(SpotTrainingStats.fromMap(const {}).hasVolume, isFalse);
    });

    test('parses counts and recent people', () {
      final stats = SpotTrainingStats.fromMap({
        'checkInCount': 28,
        'peopleCount': 12,
        'windowDays': 90,
        'recentPeople': [
          {
            'userId': 'u1',
            'displayName': 'Ada',
            'photoURL': 'https://example/a.png',
            'lastCheckedInAt': Timestamp.fromDate(
              DateTime.utc(2026, 11, 1, 12),
            ),
          },
          {
            'userId': ' ',
            'displayName': 'Skip',
          },
        ],
      });

      expect(stats.checkInCount, 28);
      expect(stats.peopleCount, 12);
      expect(stats.hasVolume, isTrue);
      expect(stats.recentPeople, hasLength(1));
      expect(stats.recentPeople.first.userId, 'u1');
      expect(stats.recentPeople.first.displayName, 'Ada');
    });

    test('hasVolume requires both counts', () {
      expect(
        const SpotTrainingStats(checkInCount: 3, peopleCount: 0).hasVolume,
        isFalse,
      );
      expect(
        const SpotTrainingStats(checkInCount: 0, peopleCount: 2).hasVolume,
        isFalse,
      );
    });
  });
}
