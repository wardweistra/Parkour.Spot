import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/spot_duplicate_merge.dart';

Spot _spot({
  String name = 'Original',
  String description = '',
  List<String>? imageUrls,
  List<String>? youtubeVideoIds,
  double latitude = 0,
  double longitude = 0,
  String? address,
  String? city,
  String? countryCode,
  String? spotAccess,
  List<String>? spotFeatures,
  Map<String, String>? spotFacilities,
  List<String>? goodFor,
  String? spotSource,
}) {
  return Spot(
    name: name,
    description: description,
    latitude: latitude,
    longitude: longitude,
    address: address,
    city: city,
    countryCode: countryCode,
    imageUrls: imageUrls,
    youtubeVideoIds: youtubeVideoIds,
    spotAccess: spotAccess,
    spotFeatures: spotFeatures,
    spotFacilities: spotFacilities,
    goodFor: goodFor,
    spotSource: spotSource,
  );
}

void main() {
  group('buildSpotDuplicateMergeUpdates', () {
    test('returns empty map when no flags set', () {
      final original = _spot(name: 'A');
      final duplicate = _spot(
        name: 'B',
        description: 'Desc',
        imageUrls: ['https://example.com/a.jpg'],
      );

      expect(
        buildSpotDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
        ),
        isEmpty,
      );
    });

    test('appends unique photos only', () {
      final original = _spot(imageUrls: ['https://example.com/a.jpg']);
      final duplicate = _spot(
        imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      );

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        transferPhotos: true,
      );

      expect(updates['imageUrls'], [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
      expect(updates['hasImages'], isTrue);
    });

    test('does not update photos when all already present', () {
      final original = _spot(imageUrls: ['https://example.com/a.jpg']);
      final duplicate = _spot(imageUrls: ['https://example.com/a.jpg']);

      expect(
        buildSpotDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
          transferPhotos: true,
        ),
        isEmpty,
      );
    });

    test('unions youtube ids', () {
      final original = _spot(youtubeVideoIds: ['aaa']);
      final duplicate = _spot(youtubeVideoIds: ['aaa', 'bbb']);

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        transferYoutubeLinks: true,
      );

      expect(updates['youtubeVideoIds'], ['aaa', 'bbb']);
    });

    test('overwrites name description location attributes when flagged', () {
      final original = _spot(
        name: 'Original',
        description: 'Old',
        latitude: 1,
        longitude: 2,
        address: 'Old St',
        spotAccess: 'public',
        spotFeatures: ['rails'],
        goodFor: ['beginners'],
      );
      final duplicate = _spot(
        name: 'Duplicate Name',
        description: 'New desc',
        latitude: 50.1,
        longitude: 4.2,
        address: 'New St',
        city: 'Brussels',
        countryCode: 'BE',
        spotAccess: 'restricted',
        spotFeatures: ['rails', 'walls'],
        spotFacilities: {'water': 'yes'},
        goodFor: ['beginners', 'balance'],
      );

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteName: true,
        overwriteDescription: true,
        overwriteLocation: true,
        overwriteSpotAttributes: true,
      );

      expect(updates['name'], 'Duplicate Name');
      expect(updates['description'], 'New desc');
      expect(updates['latitude'], 50.1);
      expect(updates['longitude'], 4.2);
      expect(updates['address'], 'New St');
      expect(updates['city'], 'Brussels');
      expect(updates['countryCode'], 'BE');
      expect(updates['spotAccess'], 'restricted');
      expect(updates['spotFeatures'], ['rails', 'walls']);
      expect(updates['spotFacilities'], {'water': 'yes'});
      expect(updates['goodFor'], ['beginners', 'balance']);
    });

    test(
      'unions goodFor and spotFeatures without dropping original values',
      () {
        final original = _spot(spotFeatures: ['walls'], goodFor: ['beginners']);
        final duplicate = _spot(
          spotFeatures: ['walls', 'rails'],
          goodFor: ['balance'],
        );

        final updates = buildSpotDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
          overwriteSpotAttributes: true,
        );

        expect(updates['spotFeatures'], ['walls', 'rails']);
        expect(updates['goodFor'], ['beginners', 'balance']);
        expect(updates.containsKey('spotAccess'), isFalse);
        expect(updates.containsKey('spotFacilities'), isFalse);
      },
    );

    test('merges facilities without dropping original keys', () {
      final original = _spot(spotFacilities: {'lighting': 'yes'});
      final duplicate = _spot(
        spotFacilities: {'covered': 'yes', 'lighting': 'no'},
      );

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteSpotAttributes: true,
      );

      expect(updates['spotFacilities'], {'lighting': 'yes', 'covered': 'yes'});
    });

    test('does not update facilities when duplicate adds nothing new', () {
      final original = _spot(
        spotFacilities: {'lighting': 'yes', 'covered': 'yes'},
      );
      final duplicate = _spot(spotFacilities: {'lighting': 'no'});

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteSpotAttributes: true,
      );

      expect(updates, isEmpty);
    });

    test('does not update goodFor or features when all already present', () {
      final original = _spot(
        spotFeatures: ['walls', 'rails'],
        goodFor: ['beginners', 'balance'],
      );
      final duplicate = _spot(spotFeatures: ['walls'], goodFor: ['beginners']);

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteSpotAttributes: true,
      );

      expect(updates, isEmpty);
    });

    test('skips overwrite fields when duplicate lacks values', () {
      final original = _spot(name: 'Original', description: 'Keep');
      final duplicate = _spot(name: '  ', description: '');

      final updates = buildSpotDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteName: true,
        overwriteDescription: true,
      );

      expect(updates, isEmpty);
    });
  });

  group('spotIsNative', () {
    test('is true when spotSource is null or blank', () {
      expect(spotIsNative(_spot()), isTrue);
      expect(spotIsNative(_spot(spotSource: '  ')), isTrue);
      expect(spotIsNative(_spot(spotSource: 'osm')), isFalse);
    });
  });
}
