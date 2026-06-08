import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/duplicate_spot_resolution_utils.dart';

void main() {
  group('duplicate spot resolution utils', () {
    test('buildConnectedDuplicateSpotIds follows recursive nearby pairs', () {
      final pairs = [
        const DuplicateSpotPairRef(
          spot1Id: 'a',
          spot2Id: 'b',
          distanceMeters: 12,
        ),
        const DuplicateSpotPairRef(
          spot1Id: 'b',
          spot2Id: 'c',
          distanceMeters: 48,
        ),
        const DuplicateSpotPairRef(
          spot1Id: 'c',
          spot2Id: 'd',
          distanceMeters: 51,
        ),
      ];

      final cluster = buildConnectedDuplicateSpotIds(
        pairs: pairs,
        startIndex: 0,
      );

      expect(cluster, {'a', 'b', 'c'});
    });

    test('findPairIndicesWithinCluster returns resolved in-cluster pairs', () {
      final pairs = [
        const DuplicateSpotPairRef(
          spot1Id: 'a',
          spot2Id: 'b',
          distanceMeters: 12,
        ),
        const DuplicateSpotPairRef(
          spot1Id: 'b',
          spot2Id: 'c',
          distanceMeters: 48,
        ),
        const DuplicateSpotPairRef(
          spot1Id: 'c',
          spot2Id: 'd',
          distanceMeters: 40,
        ),
      ];

      final indices = findPairIndicesWithinCluster(
        pairs: pairs,
        clusterSpotIds: {'a', 'b', 'c'},
      );

      expect(indices, [0, 1]);
    });

    test('buildDuplicateNativeSpotPreview merges selected sources', () {
      final spotA = Spot(
        id: 'a',
        name: 'Title A',
        description: 'Description A',
        latitude: 52,
        longitude: 4,
        imageUrls: const ['photo-a', 'shared-photo'],
        youtubeVideoIds: const ['video-a'],
        spotFeatures: const ['walls_low'],
      );
      final spotB = Spot(
        id: 'b',
        name: 'Title B',
        description: 'Description B',
        latitude: 53,
        longitude: 5,
        address: 'Address B',
        city: 'Rotterdam',
        countryCode: 'NL',
        imageUrls: const ['shared-photo', 'photo-b'],
        youtubeVideoIds: const ['video-b'],
        spotAccess: 'public',
        spotFeatures: const ['bars_low'],
        goodFor: const ['vaults'],
      );

      final preview = buildDuplicateNativeSpotPreview(
        spots: [spotA, spotB],
        baseSpotId: 'a',
        titleSpotId: 'b',
        descriptionSpotId: 'a',
        locationSpotId: 'b',
        attributesSpotId: 'b',
        photoSpotIds: {'a', 'b'},
        youtubeSpotIds: {'b'},
      );

      expect(preview.name, 'Title B');
      expect(preview.description, 'Description A');
      expect(preview.latitude, 53);
      expect(preview.longitude, 5);
      expect(preview.address, 'Address B');
      expect(preview.imageUrls, ['photo-a', 'shared-photo', 'photo-b']);
      expect(preview.youtubeVideoIds, ['video-b']);
      expect(preview.spotAccess, 'public');
      expect(preview.spotFeatures, ['bars_low']);
      expect(preview.goodFor, ['vaults']);
      expect(preview.spotSource, isNull);
      expect(preview.duplicateOf, isNull);
      expect(preview.createdFromCreateNative, isTrue);
    });
  });
}
