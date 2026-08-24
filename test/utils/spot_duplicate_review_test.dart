import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/spot_duplicate_review.dart';

Spot _spot({
  String name = 'Central Rails',
  String description = 'Long rail line',
  List<String>? imageUrls = const ['https://cdn.example.com/a.jpg'],
  List<String>? youtubeVideoIds = const ['abc123xyz'],
  double latitude = 50.8,
  double longitude = 4.3,
  String? address = 'Brussels',
  String? city = 'Brussels',
  String? countryCode = 'BE',
  String? spotAccess = 'public',
  List<String>? spotFeatures = const ['rails'],
  Map<String, String>? spotFacilities = const {'toilet': 'yes'},
  List<String>? goodFor = const ['vaults'],
  String? duplicateOf = 'native-1',
  bool hidden = false,
  double? ranking,
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
    duplicateOf: duplicateOf,
    hidden: hidden,
    ranking: ranking,
  );
}

void main() {
  group('parseSpotDuplicateChangedFieldGroups', () {
    test('keeps known groups and drops unknown or blank values', () {
      expect(
        parseSpotDuplicateChangedFieldGroups(const [
          'name',
          'location',
          'unknown',
          ' name ',
          '',
        ]),
        [SpotDuplicateFieldGroup.name, SpotDuplicateFieldGroup.location],
      );
    });
  });

  group('changedSpotDuplicateFieldGroups', () {
    test('returns empty when transferable fields match', () {
      expect(
        changedSpotDuplicateFieldGroups(previous: _spot(), current: _spot()),
        isEmpty,
      );
    });

    test('detects each field group', () {
      final previous = _spot();
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(name: 'Renamed'),
        ),
        [SpotDuplicateFieldGroup.name],
      );
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(description: 'Updated'),
        ),
        [SpotDuplicateFieldGroup.description],
      );
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(imageUrls: const ['https://cdn.example.com/b.jpg']),
        ),
        [SpotDuplicateFieldGroup.photos],
      );
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(youtubeVideoIds: const ['newid12345']),
        ),
        [SpotDuplicateFieldGroup.youtube],
      );
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(address: 'Ghent'),
        ),
        [SpotDuplicateFieldGroup.location],
      );
      expect(
        changedSpotDuplicateFieldGroups(
          previous: previous,
          current: _spot(spotAccess: 'restricted'),
        ),
        [SpotDuplicateFieldGroup.attributes],
      );
    });

    test('treats empty and missing description as equal', () {
      expect(
        changedSpotDuplicateFieldGroups(
          previous: _spot(description: ''),
          current: _spot(description: '   '),
        ),
        isEmpty,
      );
    });

    test('ignores hidden ranking and other meta fields', () {
      expect(
        changedSpotDuplicateFieldGroups(
          previous: _spot(hidden: false, ranking: 1),
          current: _spot(hidden: true, ranking: 99),
        ),
        isEmpty,
      );
    });
  });

  group('buildSpotDuplicateReviewBaseline', () {
    test('snapshots transferable fields and omits empty optionals', () {
      final spot = _spot(description: '  ', address: null);
      final baseline = buildSpotDuplicateReviewBaseline(spot);
      expect(baseline['name'], 'Central Rails');
      expect(baseline.containsKey('description'), isFalse);
      expect(baseline.containsKey('address'), isFalse);
      expect(baseline['imageUrls'], ['https://cdn.example.com/a.jpg']);
      expect(baseline['youtubeVideoIds'], ['abc123xyz']);
      expect(baseline['latitude'], 50.8);
      expect(baseline['city'], 'Brussels');
    });
  });
}
