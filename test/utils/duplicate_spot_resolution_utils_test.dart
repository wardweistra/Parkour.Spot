import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/duplicate_spot_resolution_utils.dart';

void main() {
  group('duplicate spot resolution utils', () {
    test('firestore helpers coerce web interop values', () {
      expect(firestoreInt(3), 3);
      expect(firestoreInt(3.9), 3);
      expect(firestoreInt('bad'), 0);
      expect(firestoreIntSet([1, 2.0, 3]), {1, 2, 3});
      expect(
        firestoreMap({
          'nested': {'status': 'resolved_to_native'},
        }),
        {
          'nested': {'status': 'resolved_to_native'},
        },
      );
      expect(
        isPairResolvedToNative({
          '0': {'status': 'resolved_to_native'},
        }, 0),
        isTrue,
      );
      expect(
        isPairResolvedToNative({
          '0': {'status': 'pending'},
        }, 0),
        isFalse,
      );
    });

    test('isSpotAlreadyMarkedAsDuplicate detects duplicateOf', () {
      expect(
        isSpotAlreadyMarkedAsDuplicate(
          Spot(name: 'A', description: '', latitude: 0, longitude: 0),
        ),
        isFalse,
      );
      expect(
        isSpotAlreadyMarkedAsDuplicate(
          Spot(
            name: 'B',
            description: '',
            latitude: 0,
            longitude: 0,
            duplicateOf: 'original-id',
          ),
        ),
        isTrue,
      );
      expect(
        isSpotAlreadyMarkedAsDuplicate(
          Spot(
            name: 'C',
            description: '',
            latitude: 0,
            longitude: 0,
            duplicateOf: '  ',
          ),
        ),
        isFalse,
      );
    });

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
        accessSpotId: 'b',
        facilitiesSpotIds: {'b'},
        featureSpotIds: {'a', 'b'},
        goodForSpotIds: {'b'},
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
      expect(preview.spotFeatures, ['walls_low', 'bars_low']);
      expect(preview.goodFor, ['vaults']);
      expect(preview.spotSource, isNull);
      expect(preview.duplicateOf, isNull);
      expect(preview.createdFromCreateNative, isTrue);
    });

    test(
      'buildDuplicateNativeSpotPreview unions feature and good-for tags separately',
      () {
        final spotA = Spot(
          id: 'a',
          name: 'A',
          description: '',
          latitude: 52,
          longitude: 4,
          spotFeatures: const ['walls_low'],
          goodFor: const ['vaults'],
        );
        final spotB = Spot(
          id: 'b',
          name: 'B',
          description: '',
          latitude: 52.0001,
          longitude: 4.0001,
          spotFeatures: const ['bars_low', 'walls_low'],
          goodFor: const ['precisions'],
        );

        final preview = buildDuplicateNativeSpotPreview(
          spots: [spotA, spotB],
          baseSpotId: 'a',
          titleSpotId: 'a',
          descriptionSpotId: 'a',
          locationSpotId: 'a',
          accessSpotId: 'a',
          facilitiesSpotIds: {'a'},
          featureSpotIds: {'a', 'b'},
          goodForSpotIds: {'a', 'b'},
          photoSpotIds: const {},
          youtubeSpotIds: const {},
        );

        expect(preview.spotFeatures, ['walls_low', 'bars_low']);
        expect(preview.goodFor, ['vaults', 'precisions']);
      },
    );

    test(
      'buildDuplicateNativeSpotPreview merges facilities across selected spots',
      () {
        final spotA = Spot(
          id: 'a',
          name: 'A',
          description: '',
          latitude: 52,
          longitude: 4,
          spotFacilities: const {'lighting': 'yes'},
        );
        final spotB = Spot(
          id: 'b',
          name: 'B',
          description: '',
          latitude: 52.0001,
          longitude: 4.0001,
          spotFacilities: const {'covered': 'yes', 'lighting': 'no'},
        );

        final preview = buildDuplicateNativeSpotPreview(
          spots: [spotA, spotB],
          baseSpotId: 'a',
          titleSpotId: 'a',
          descriptionSpotId: 'a',
          locationSpotId: 'a',
          accessSpotId: 'a',
          facilitiesSpotIds: {'a', 'b'},
          featureSpotIds: const {},
          goodForSpotIds: const {},
          photoSpotIds: const {},
          youtubeSpotIds: const {},
        );

        expect(preview.spotFacilities, {'lighting': 'yes', 'covered': 'yes'});
      },
    );

    test('sortSpotsByOptionalDetailRichness orders richest spot first', () {
      final sparse = Spot(
        id: 'sparse',
        name: 'Sparse',
        description: '',
        latitude: 52,
        longitude: 4,
      );
      final rich = Spot(
        id: 'rich',
        name: 'Rich',
        description: 'A full write-up',
        latitude: 52.0001,
        longitude: 4.0001,
        imageUrls: const ['one', 'two'],
        spotAccess: 'public',
        spotFeatures: const ['walls_low', 'bars_low'],
        goodFor: const ['vaults'],
        spotFacilities: const {'parking': 'true'},
      );

      final ordered = sortSpotsByOptionalDetailRichness([sparse, rich]);

      expect(ordered.map((spot) => spot.id).toList(), ['rich', 'sparse']);
      expect(
        duplicateClusterOptionalDetailScore(rich),
        greaterThan(duplicateClusterOptionalDetailScore(sparse)),
      );
    });

    test(
      'buildDuplicateClusterMergeDefaults picks richest basis and sole providers',
      () {
        final basisCandidate = Spot(
          id: 'basis',
          name: 'Basis title',
          description: 'Shared description',
          latitude: 52,
          longitude: 4,
          imageUrls: const ['photo-a', 'photo-b'],
          spotAccess: 'public',
          spotFeatures: const ['walls_low', 'bars_low'],
          goodFor: const ['vaults'],
          spotFacilities: const {'parking': 'true'},
        );
        final uniqueDetails = Spot(
          id: 'unique',
          name: 'Unique title',
          description: '',
          latitude: 52.0001,
          longitude: 4.0001,
          address: 'Only address',
          goodFor: const ['precisions'],
          youtubeVideoIds: const ['video-only'],
        );

        final defaults = buildDuplicateClusterMergeDefaults([
          uniqueDetails,
          basisCandidate,
        ]);

        expect(defaults.basisSpotId, 'basis');
        expect(defaults.titleSpotId, 'basis');
        expect(defaults.descriptionSpotId, 'basis');
        expect(defaults.locationSpotId, 'unique');
        expect(defaults.accessSpotId, 'basis');
        expect(defaults.facilitiesSpotIds, {'basis'});
        expect(defaults.featureSpotIds, {'basis'});
        expect(defaults.goodForSpotIds, {'basis', 'unique'});
        expect(defaults.photoSpotIds, {'basis'});
        expect(defaults.youtubeSpotIds, {'unique'});
      },
    );

    test('isParkourSpotNativeSpot treats null spotSource as native', () {
      expect(
        isParkourSpotNativeSpot(
          Spot(name: 'Native', description: '', latitude: 0, longitude: 0),
        ),
        isTrue,
      );
      expect(
        isParkourSpotNativeSpot(
          Spot(
            name: 'External',
            description: '',
            latitude: 0,
            longitude: 0,
            spotSource: 'some-source',
          ),
        ),
        isFalse,
      );
    });

    test(
      'pickDuplicateClusterBasisSpotId prefers native over richer external',
      () {
        final native = Spot(
          id: 'native',
          name: 'Native',
          description: '',
          latitude: 52,
          longitude: 4,
        );
        final external = Spot(
          id: 'external',
          name: 'External',
          description: 'Much more detail',
          latitude: 52.0001,
          longitude: 4.0001,
          imageUrls: const ['photo-a', 'photo-b'],
          spotAccess: 'public',
          spotFeatures: const ['walls_low', 'bars_low'],
          goodFor: const ['vaults'],
          spotFacilities: const {'parking': 'true'},
          spotSource: 'external-source',
        );

        expect(pickDuplicateClusterBasisSpotId([external, native]), 'native');
      },
    );

    test(
      'pickDuplicateClusterBasisSpotId picks richest among multiple natives',
      () {
        final sparseNative = Spot(
          id: 'sparse-native',
          name: 'Sparse native',
          description: '',
          latitude: 52,
          longitude: 4,
        );
        final richNative = Spot(
          id: 'rich-native',
          name: 'Rich native',
          description: 'Detailed native spot',
          latitude: 52.0001,
          longitude: 4.0001,
          imageUrls: const ['photo-a'],
          spotAccess: 'public',
        );

        expect(
          pickDuplicateClusterBasisSpotId([sparseNative, richNative]),
          'rich-native',
        );
      },
    );

    test(
      'pickDuplicateClusterBasisSpotId falls back to richest external when no natives',
      () {
        final sparseExternal = Spot(
          id: 'sparse-external',
          name: 'Sparse external',
          description: '',
          latitude: 52,
          longitude: 4,
          spotSource: 'source-a',
        );
        final richExternal = Spot(
          id: 'rich-external',
          name: 'Rich external',
          description: 'Detailed external spot',
          latitude: 52.0001,
          longitude: 4.0001,
          imageUrls: const ['photo-a', 'photo-b'],
          spotSource: 'source-b',
        );

        expect(
          pickDuplicateClusterBasisSpotId([sparseExternal, richExternal]),
          'rich-external',
        );
      },
    );

    test(
      'buildDuplicateClusterMergeDefaults uses native as basis when present',
      () {
        final native = Spot(
          id: 'native',
          name: 'Native title',
          description: '',
          latitude: 52,
          longitude: 4,
        );
        final external = Spot(
          id: 'external',
          name: 'External title',
          description: 'Rich external description',
          latitude: 52.0001,
          longitude: 4.0001,
          address: 'Only address',
          imageUrls: const ['photo-a', 'photo-b'],
          youtubeVideoIds: const ['video-only'],
          spotSource: 'external-source',
        );

        final defaults = buildDuplicateClusterMergeDefaults([external, native]);

        expect(defaults.basisSpotId, 'native');
        expect(defaults.titleSpotId, 'native');
        expect(defaults.locationSpotId, 'external');
        expect(defaults.photoSpotIds, {'external'});
        expect(defaults.youtubeSpotIds, {'external'});
      },
    );

    test(
      'buildDuplicateNativeSpotPreview honors separate feature and good-for picks',
      () {
        final spotA = Spot(
          id: 'a',
          name: 'A',
          description: '',
          latitude: 52,
          longitude: 4,
          spotFeatures: const ['walls_low'],
          goodFor: const ['vaults'],
        );
        final spotB = Spot(
          id: 'b',
          name: 'B',
          description: '',
          latitude: 52.0001,
          longitude: 4.0001,
          spotFeatures: const ['bars_low'],
          goodFor: const ['precisions'],
        );

        final preview = buildDuplicateNativeSpotPreview(
          spots: [spotA, spotB],
          baseSpotId: 'a',
          titleSpotId: 'a',
          descriptionSpotId: 'a',
          locationSpotId: 'a',
          accessSpotId: 'a',
          facilitiesSpotIds: {'a'},
          featureSpotIds: {'a'},
          goodForSpotIds: {'b'},
          photoSpotIds: const {},
          youtubeSpotIds: const {},
        );

        expect(preview.spotFeatures, ['walls_low']);
        expect(preview.goodFor, ['precisions']);
      },
    );
  });
}
