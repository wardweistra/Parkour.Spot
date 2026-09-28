import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
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

  group('spot duplicate field comparison', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('hydrates a display spot from the stored baseline', () {
      final hydrated = spotFromDuplicateReviewBaseline(
        buildSpotDuplicateReviewBaseline(_spot()),
      );
      expect(hydrated?.name, 'Central Rails');
      expect(hydrated?.city, 'Brussels');
      expect(spotFromDuplicateReviewBaseline(null), isNull);
    });

    test('name shows from, to, native, and a match', () {
      final comparison = buildSpotDuplicateFieldComparison(
        current: _spot(name: 'Updated name'),
        previous: _spot(),
        native: _spot(),
        group: SpotDuplicateFieldGroup.name,
        l10n: l10n,
      );
      expect(comparison.previousUnavailable, isFalse);
      expect(comparison.nativeMatchesPrevious, isTrue);
      expect(comparison.lines.single.from, 'Central Rails');
      expect(comparison.lines.single.to, 'Updated name');
      expect(comparison.lines.single.native, 'Central Rails');
    });

    test(
      'name reports when the native value differs from the previous one',
      () {
        final comparison = buildSpotDuplicateFieldComparison(
          current: _spot(name: 'Updated name'),
          previous: _spot(),
          native: _spot(name: 'Native rails'),
          group: SpotDuplicateFieldGroup.name,
          l10n: l10n,
        );
        expect(comparison.nativeMatchesPrevious, isFalse);
        expect(comparison.lines.single.native, 'Native rails');
      },
    );

    test('missing baseline and native do not claim a match', () {
      final comparison = buildSpotDuplicateFieldComparison(
        current: _spot(name: 'Updated name'),
        previous: null,
        native: null,
        group: SpotDuplicateFieldGroup.name,
        l10n: l10n,
      );
      expect(comparison.previousUnavailable, isTrue);
      expect(comparison.nativeUnavailable, isTrue);
      expect(comparison.nativeMatchesPrevious, isNull);
      expect(comparison.currentSummary, 'Updated name');
      expect(comparison.lines, isEmpty);
    });

    test('location lists only the sub-field that changed', () {
      final comparison = buildSpotDuplicateFieldComparison(
        current: _spot(address: 'Ghent'),
        previous: _spot(),
        native: _spot(),
        group: SpotDuplicateFieldGroup.location,
        l10n: l10n,
      );
      expect(comparison.lines.map((line) => line.label), ['Address']);
      expect(comparison.lines.single.from, 'Brussels');
      expect(comparison.lines.single.to, 'Ghent');
      expect(comparison.lines.single.native, 'Brussels');
      expect(comparison.nativeMatchesPrevious, isTrue);
    });

    test('description keeps the full text', () {
      final description = 'A' * 120;
      final comparison = buildSpotDuplicateFieldComparison(
        current: _spot(description: description),
        previous: _spot(description: 'Short'),
        native: _spot(description: 'Short'),
        group: SpotDuplicateFieldGroup.description,
        l10n: l10n,
      );
      expect(comparison.lines.single.from, 'Short');
      expect(comparison.lines.single.to, description);
    });

    test('photos note when the count stays the same but contents change', () {
      final comparison = buildSpotDuplicateFieldComparison(
        current: _spot(
          imageUrls: const [
            'https://cdn.example.com/a.jpg',
            'https://cdn.example.com/c.jpg',
          ],
        ),
        previous: _spot(
          imageUrls: const [
            'https://cdn.example.com/a.jpg',
            'https://cdn.example.com/b.jpg',
          ],
        ),
        native: _spot(
          imageUrls: const [
            'https://cdn.example.com/a.jpg',
            'https://cdn.example.com/b.jpg',
          ],
        ),
        group: SpotDuplicateFieldGroup.photos,
        l10n: l10n,
      );
      expect(comparison.lines.single.from, '2 photos');
      expect(comparison.lines.single.to, '2 photos');
      expect(comparison.lines.single.contentsChanged, isTrue);
      expect(comparison.nativeMatchesPrevious, isTrue);
    });
  });
}
