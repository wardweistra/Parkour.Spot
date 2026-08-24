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
        spotFeatures: ['walls'],
        spotFacilities: {'water': 'yes'},
        goodFor: ['balance'],
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
      expect(updates['spotFeatures'], ['walls']);
      expect(updates['spotFacilities'], {'water': 'yes'});
      expect(updates['goodFor'], ['balance']);
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
