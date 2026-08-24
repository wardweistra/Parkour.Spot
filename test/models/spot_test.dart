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
}
