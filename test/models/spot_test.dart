import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';

Spot buildSpot({List<String>? imageUrls}) {
  return Spot(
    name: 'Test spot',
    description: 'Description',
    latitude: 46.5,
    longitude: 6.6,
    imageUrls: imageUrls,
  );
}

void main() {
  group('Spot hasImages', () {
    test('is false when imageUrls is absent', () {
      final spot = buildSpot();

      expect(spot.hasImages, isFalse);
      expect(spot.toFirestore()['hasImages'], isFalse);
    });

    test('is false when imageUrls is empty', () {
      final spot = buildSpot(imageUrls: []);

      expect(spot.hasImages, isFalse);
      expect(spot.toFirestore()['hasImages'], isFalse);
    });

    test('is true when imageUrls contains an image', () {
      final spot = buildSpot(imageUrls: ['https://example.com/image.jpg']);

      expect(spot.hasImages, isTrue);
      expect(spot.toFirestore()['hasImages'], isTrue);
    });
  });

  group('Spot duplicate pending changes', () {
    test('fromMap parses pending-change fields', () {
      final spot = Spot.fromMap({
        'name': 'Synced',
        'description': 'Desc',
        'latitude': 1.0,
        'longitude': 2.0,
        'duplicateOf': 'native-original',
        'duplicateHasPendingChanges': true,
        'duplicateChangedFields': ['name', 'location', 'unknown'],
      });
      expect(spot.duplicateHasPendingChanges, isTrue);
      expect(spot.duplicateChangedFields, ['name', 'location', 'unknown']);
      expect(spot.hasDuplicatePendingChanges, isTrue);
    });

    test('toFirestore omits duplicate review snapshot fields', () {
      final spot = Spot(
        name: 'Dup',
        description: 'Desc',
        latitude: 1,
        longitude: 2,
        duplicateOf: 'orig-id',
        duplicateHasPendingChanges: true,
        duplicateChangedFields: const ['name'],
      );
      final map = spot.toFirestore();
      expect(map.containsKey('duplicateHasPendingChanges'), isFalse);
      expect(map.containsKey('duplicateChangedFields'), isFalse);
      expect(map.containsKey('duplicateReviewBaseline'), isFalse);
    });

    test('hasDuplicatePendingChanges requires a duplicate link', () {
      final spot = Spot(
        name: 'Jam',
        description: 'Desc',
        latitude: 1,
        longitude: 2,
        duplicateHasPendingChanges: true,
      );
      expect(spot.hasDuplicatePendingChanges, isFalse);
    });
  });

  group('Spot external sync timestamps', () {
    test('fromMap parses last-seen and last-changed', () {
      final seenAt = DateTime.utc(2026, 8, 24, 10, 0);
      final changedAt = DateTime.utc(2026, 8, 20, 9, 0);
      final spot = Spot.fromMap({
        'name': 'Imported rails',
        'description': 'Desc',
        'latitude': 1.0,
        'longitude': 2.0,
        'externalSyncLastSeenAt': Timestamp.fromDate(seenAt),
        'externalSyncLastChangedAt': Timestamp.fromDate(changedAt),
      });
      expect(spot.externalSyncLastSeenAt?.toUtc(), seenAt);
      expect(spot.externalSyncLastChangedAt?.toUtc(), changedAt);
    });

    test('toFirestore includes sync timestamps when set', () {
      final seenAt = DateTime.utc(2026, 8, 24, 10, 0);
      final changedAt = DateTime.utc(2026, 8, 20, 9, 0);
      final spot = Spot(
        name: 'Imported rails',
        description: 'Desc',
        latitude: 1,
        longitude: 2,
        externalSyncLastSeenAt: seenAt,
        externalSyncLastChangedAt: changedAt,
      );
      final map = spot.toFirestore();
      expect(map['externalSyncLastSeenAt'], seenAt);
      expect(map['externalSyncLastChangedAt'], changedAt);
    });

    test('toFirestore omits sync timestamps when unset', () {
      final spot = buildSpot();
      final map = spot.toFirestore();
      expect(map.containsKey('externalSyncLastSeenAt'), isFalse);
      expect(map.containsKey('externalSyncLastChangedAt'), isFalse);
    });
  });
}
