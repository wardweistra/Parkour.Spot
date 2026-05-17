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
        'imageUrls': ['https://img.example/1.jpg', 'https://img.example/2.jpg'],
        'websiteUrl': 'https://parkour.spot/events/sunset-jam',
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'latitude': 52.3702,
        'longitude': 4.8952,
        'address': 'Amsterdam, Netherlands',
        'spotIds': ['spot-a', 'spot-b'],
        'spotListIds': ['list-1'],
        'createdBy': 'admin-uid',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(event.id, 'event-1');
      expect(event.title, 'Sunset Jam');
      expect(event.description, 'Open training session');
      expect(event.imageUrls, [
        'https://img.example/1.jpg',
        'https://img.example/2.jpg',
      ]);
      expect(event.websiteUrl, 'https://parkour.spot/events/sunset-jam');
      expect(event.startAt.toUtc(), startAt);
      expect(event.endAt?.toUtc(), endAt);
      expect(event.latitude, 52.3702);
      expect(event.longitude, 4.8952);
      expect(event.address, 'Amsterdam, Netherlands');
      expect(event.spotIds, ['spot-a', 'spot-b']);
      expect(event.spotListIds, ['list-1']);
      expect(event.createdBy, 'admin-uid');
      expect(event.createdAt?.toUtc(), createdAt);
      expect(event.updatedAt?.toUtc(), updatedAt);
      expect(event.duplicateOf, isNull);
      expect(event.isNativeEvent, isTrue);
    });

    test('fromMap parses duplicateOf and external source for isNativeEvent', () {
      final event = ParkourEvent.fromMap({
        'title': 'Synced',
        'startAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'spotIds': const ['spot-x'],
        'eventSourceId': 'ics-source',
        'duplicateOf': 'native-original',
      });
      expect(event.duplicateOf, 'native-original');
      expect(event.isNativeEvent, isFalse);
    });

    test('toFirestore keeps linked spots and trims description', () {
      final event = ParkourEvent(
        id: 'event-2',
        title: 'Community Session',
        description: '  Meet and train  ',
        imageUrls: const ['https://img.example/event.jpg'],
        websiteUrl: ' https://event.example/info ',
        startAt: DateTime.utc(2026, 6, 1, 14, 0),
        endAt: DateTime.utc(2026, 6, 1, 16, 0),
        latitude: 48.8566,
        longitude: 2.3522,
        address: '  Paris, France ',
        spotIds: const ['spot-c', 'spot-d'],
        createdBy: 'admin-uid',
        createdAt: DateTime.utc(2026, 5, 25, 8, 0),
        updatedAt: DateTime.utc(2026, 5, 25, 9, 0),
      );

      final map = event.toFirestore();

      expect(map['title'], 'Community Session');
      expect(map['description'], 'Meet and train');
      expect(map['imageUrls'], ['https://img.example/event.jpg']);
      expect(map['websiteUrl'], 'https://event.example/info');
      expect(map['spotIds'], ['spot-c', 'spot-d']);
      expect(map['spotListIds'], isEmpty);
      expect(map['startAt'], DateTime.utc(2026, 6, 1, 14, 0));
      expect(map['endAt'], DateTime.utc(2026, 6, 1, 16, 0));
      expect(map['latitude'], 48.8566);
      expect(map['longitude'], 2.3522);
      expect(map['address'], 'Paris, France');
      expect(map['createdBy'], 'admin-uid');
      expect(map['createdAt'], DateTime.utc(2026, 5, 25, 8, 0));
      expect(map['updatedAt'], DateTime.utc(2026, 5, 25, 9, 0));
    });

    test('fromMap defaults spotListIds to empty list', () {
      final event = ParkourEvent.fromMap({
        'title': 'No lists',
        'startAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'spotIds': const <String>[],
      });
      expect(event.spotListIds, isEmpty);
    });

    test('toFirestore includes duplicateOf when non-empty', () {
      final event = ParkourEvent(
        title: 'Dup',
        startAt: DateTime.utc(2026, 7, 1, 12, 0),
        spotIds: const ['spot-z'],
        duplicateOf: '  orig-id  ',
      );
      final map = event.toFirestore();
      expect(map['duplicateOf'], 'orig-id');
    });
  });
}
