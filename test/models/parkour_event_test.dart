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
        'isDateOnly': true,
        'timeZone': 'Europe/Paris',
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
      expect(event.isDateOnly, isTrue);
      expect(event.timeZone, 'Europe/Paris');
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

    test(
      'fromMap parses duplicateOf and external source for isNativeEvent',
      () {
        final event = ParkourEvent.fromMap({
          'title': 'Synced',
          'startAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
          'spotIds': const ['spot-x'],
          'eventSourceId': 'ics-source',
          'duplicateOf': 'native-original',
        });
        expect(event.duplicateOf, 'native-original');
        expect(event.isNativeEvent, isFalse);
      },
    );

    test('toFirestore keeps linked spots and trims description', () {
      final event = ParkourEvent(
        id: 'event-2',
        title: 'Community Session',
        description: '  Meet and train  ',
        imageUrls: const ['https://img.example/event.jpg'],
        websiteUrl: ' https://event.example/info ',
        startAt: DateTime.utc(2026, 6, 1, 14, 0),
        endAt: DateTime.utc(2026, 6, 1, 16, 0),
        isDateOnly: false,
        timeZone: 'Europe/Paris',
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
      expect(map['timeZone'], 'Europe/Paris');
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
      expect(map.containsKey('isDateOnly'), isFalse);
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

    test('toFirestore includes date-only schedule fields when set', () {
      final event = ParkourEvent(
        title: 'Holiday Jam',
        startAt: DateTime.utc(2026, 12, 24),
        endAt: DateTime.utc(2026, 12, 26, 23, 59, 59, 999),
        isDateOnly: true,
        timeZone: 'Europe/Paris',
      );
      final map = event.toFirestore();
      expect(map['isDateOnly'], isTrue);
      expect(map['timeZone'], 'Europe/Paris');
    });

    test('fromMap parses createdFromCreateNative', () {
      final event = ParkourEvent.fromMap({
        'title': 'Promoted',
        'startAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'spotIds': const <String>[],
        'createdFromCreateNative': true,
      });
      expect(event.createdFromCreateNative, isTrue);
      expect(event.isNativeEvent, isTrue);
    });

    test('toFirestore includes createdFromCreateNative when true', () {
      final event = ParkourEvent(
        title: 'Promoted',
        startAt: DateTime.utc(2026, 1, 1, 12, 0),
        spotIds: const <String>[],
        createdBy: 'mod-uid',
        createdFromCreateNative: true,
      );
      final map = event.toFirestore();
      expect(map['createdFromCreateNative'], isTrue);
      expect(map.containsKey('eventSourceId'), isFalse);
    });

    test('native copy from external omits import fields', () {
      final external = ParkourEvent(
        title: 'ICS Jam',
        description: 'Imported session',
        imageUrls: const ['https://img.example/ics.jpg'],
        websiteUrl: 'https://example.com/event',
        startAt: DateTime.utc(2026, 8, 1, 18, 0),
        endAt: DateTime.utc(2026, 8, 1, 20, 0),
        latitude: 51.0,
        longitude: 5.0,
        address: 'Utrecht',
        spotIds: const ['spot-1'],
        spotListIds: const ['list-1'],
        eventSourceId: 'source-abc',
        eventSourceName: 'Community calendar',
        externalEventUid: 'uid-1',
        externalEventKey: 'key-1',
        createdBy: 'external-event-sync',
      );
      expect(external.isNativeEvent, isFalse);

      final native = ParkourEvent(
        title: external.title,
        description: external.description,
        imageUrls: external.imageUrls,
        websiteUrl: external.websiteUrl,
        startAt: external.startAt,
        endAt: external.endAt,
        latitude: external.latitude,
        longitude: external.longitude,
        address: external.address,
        spotIds: external.spotIds,
        spotListIds: external.spotListIds,
        createdBy: 'moderator-uid',
        createdAt: DateTime.utc(2026, 5, 17, 12, 0),
        updatedAt: DateTime.utc(2026, 5, 17, 12, 0),
        duplicateOf: null,
        createdFromCreateNative: true,
      );

      expect(native.isNativeEvent, isTrue);
      final map = native.toFirestore();
      expect(map['title'], 'ICS Jam');
      expect(map['spotIds'], ['spot-1']);
      expect(map['spotListIds'], ['list-1']);
      expect(map.containsKey('eventSourceId'), isFalse);
      expect(map.containsKey('eventSourceName'), isFalse);
      expect(map.containsKey('externalEventUid'), isFalse);
      expect(map.containsKey('externalEventKey'), isFalse);
      expect(map['createdFromCreateNative'], isTrue);
    });
  });
}
