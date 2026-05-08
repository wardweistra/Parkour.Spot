import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';

void main() {
  group('ParkourEvent', () {
    test('fromMap parses required fields and linked spot IDs', () {
      final startAt = DateTime.utc(2026, 5, 8, 17, 0);
      final endAt = DateTime.utc(2026, 5, 8, 19, 0);
      final createdAt = DateTime.utc(2026, 5, 1, 10, 0);
      final updatedAt = DateTime.utc(2026, 5, 2, 10, 0);

      final event = ParkourEvent.fromMap({
        'id': 'event-1',
        'title': 'Sunset Jam',
        'description': 'Open training session',
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'spotIds': ['spot-a', 'spot-b'],
        'createdBy': 'admin-uid',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(event.id, 'event-1');
      expect(event.title, 'Sunset Jam');
      expect(event.description, 'Open training session');
      expect(event.startAt, startAt);
      expect(event.endAt, endAt);
      expect(event.spotIds, ['spot-a', 'spot-b']);
      expect(event.createdBy, 'admin-uid');
      expect(event.createdAt, createdAt);
      expect(event.updatedAt, updatedAt);
    });

    test('toFirestore keeps linked spots and trims description', () {
      final event = ParkourEvent(
        id: 'event-2',
        title: 'Community Session',
        description: '  Meet and train  ',
        startAt: DateTime.utc(2026, 6, 1, 14, 0),
        endAt: DateTime.utc(2026, 6, 1, 16, 0),
        spotIds: const ['spot-c', 'spot-d'],
        createdBy: 'admin-uid',
        createdAt: DateTime.utc(2026, 5, 25, 8, 0),
        updatedAt: DateTime.utc(2026, 5, 25, 9, 0),
      );

      final map = event.toFirestore();

      expect(map['title'], 'Community Session');
      expect(map['description'], 'Meet and train');
      expect(map['spotIds'], ['spot-c', 'spot-d']);
      expect(map['startAt'], DateTime.utc(2026, 6, 1, 14, 0));
      expect(map['endAt'], DateTime.utc(2026, 6, 1, 16, 0));
      expect(map['createdBy'], 'admin-uid');
      expect(map['createdAt'], DateTime.utc(2026, 5, 25, 8, 0));
      expect(map['updatedAt'], DateTime.utc(2026, 5, 25, 9, 0));
    });
  });
}
