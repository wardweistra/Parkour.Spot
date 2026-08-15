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
}
