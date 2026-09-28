import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_duplicate_review.dart';

ParkourEvent _event({
  String title = 'Jam Session',
  String? description = 'Bring water',
  List<String> imageUrls = const ['https://cdn.example.com/a.jpg'],
  String? websiteUrl = 'https://example.com/jam',
  DateTime? startAt,
  DateTime? endAt,
  bool isDateOnly = false,
  String? timeZone = 'Europe/Brussels',
  String? timeZoneSource = 'feed',
  double? latitude = 50.8,
  double? longitude = 4.3,
  String? address = 'Brussels',
  String? city = 'Brussels',
  String? countryCode = 'BE',
  List<String> spotIds = const ['spot-1'],
  List<String> spotListIds = const ['list-1'],
}) {
  return ParkourEvent(
    title: title,
    description: description,
    imageUrls: imageUrls,
    websiteUrl: websiteUrl,
    startAt: startAt ?? DateTime.utc(2026, 5, 13, 10),
    endAt: endAt ?? DateTime.utc(2026, 5, 13, 12),
    isDateOnly: isDateOnly,
    timeZone: timeZone,
    timeZoneSource: timeZoneSource,
    latitude: latitude,
    longitude: longitude,
    address: address,
    city: city,
    countryCode: countryCode,
    spotIds: spotIds,
    spotListIds: spotListIds,
    duplicateOf: 'native-1',
  );
}

void main() {
  group('parseDuplicateChangedFieldGroups', () {
    test('keeps known groups and drops unknown or blank values', () {
      expect(
        parseDuplicateChangedFieldGroups(const [
          'title',
          'schedule',
          'unknown',
          ' title ',
          '',
        ]),
        [EventDuplicateFieldGroup.title, EventDuplicateFieldGroup.schedule],
      );
    });
  });

  group('changedEventDuplicateFieldGroups', () {
    test('returns empty when transferable fields match', () {
      expect(
        changedEventDuplicateFieldGroups(previous: _event(), current: _event()),
        isEmpty,
      );
    });

    test('detects each field group', () {
      final previous = _event();
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(title: 'Renamed'),
        ),
        [EventDuplicateFieldGroup.title],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(description: 'Updated'),
        ),
        [EventDuplicateFieldGroup.description],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(websiteUrl: 'https://example.com/new'),
        ),
        [EventDuplicateFieldGroup.website],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(imageUrls: const ['https://cdn.example.com/b.jpg']),
        ),
        [EventDuplicateFieldGroup.photos],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(spotIds: const ['spot-2']),
        ),
        [EventDuplicateFieldGroup.linkedSpots],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(address: 'Ghent'),
        ),
        [EventDuplicateFieldGroup.location],
      );
      expect(
        changedEventDuplicateFieldGroups(
          previous: previous,
          current: _event(startAt: DateTime.utc(2026, 5, 14, 10)),
        ),
        [EventDuplicateFieldGroup.schedule],
      );
    });

    test('treats empty and missing description as equal', () {
      expect(
        changedEventDuplicateFieldGroups(
          previous: _event(description: ''),
          current: _event(description: null),
        ),
        isEmpty,
      );
    });
  });

  group('buildEventDuplicateReviewBaseline', () {
    test('snapshots transferable fields and omits empty optionals', () {
      final event = _event(description: '  ', websiteUrl: null);
      final baseline = buildEventDuplicateReviewBaseline(event);
      expect(baseline['title'], 'Jam Session');
      expect(baseline.containsKey('description'), isFalse);
      expect(baseline.containsKey('websiteUrl'), isFalse);
      expect(baseline['imageUrls'], ['https://cdn.example.com/a.jpg']);
      expect(baseline['spotIds'], ['spot-1']);
      expect(baseline['startAt'], isA<Timestamp>());
      expect(
        (baseline['startAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 5, 13, 10),
      );
    });
  });

  group('event duplicate field comparison', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('hydrates a display event from the stored baseline', () {
      final hydrated = eventFromDuplicateReviewBaseline(
        buildEventDuplicateReviewBaseline(_event()),
      );
      expect(hydrated?.title, 'Jam Session');
      expect(hydrated?.city, 'Brussels');
      expect(eventFromDuplicateReviewBaseline(null), isNull);
    });

    test('title shows from, to, native, and a match', () {
      final comparison = buildEventDuplicateFieldComparison(
        context: null,
        current: _event(title: 'Updated title'),
        previous: _event(),
        native: _event(),
        group: EventDuplicateFieldGroup.title,
        l10n: l10n,
      );
      expect(comparison.nativeMatchesPrevious, isTrue);
      expect(comparison.lines.single.from, 'Jam Session');
      expect(comparison.lines.single.to, 'Updated title');
      expect(comparison.lines.single.native, 'Jam Session');
    });

    test(
      'title reports when the native value differs from the previous one',
      () {
        final comparison = buildEventDuplicateFieldComparison(
          context: null,
          current: _event(title: 'Updated title'),
          previous: _event(),
          native: _event(title: 'Native jam'),
          group: EventDuplicateFieldGroup.title,
          l10n: l10n,
        );
        expect(comparison.nativeMatchesPrevious, isFalse);
        expect(comparison.lines.single.native, 'Native jam');
      },
    );

    test('missing baseline and native do not claim a match', () {
      final comparison = buildEventDuplicateFieldComparison(
        context: null,
        current: _event(title: 'Updated title'),
        previous: null,
        native: null,
        group: EventDuplicateFieldGroup.title,
        l10n: l10n,
      );
      expect(comparison.previousUnavailable, isTrue);
      expect(comparison.nativeUnavailable, isTrue);
      expect(comparison.nativeMatchesPrevious, isNull);
      expect(comparison.currentSummary, 'Updated title');
    });

    test('location lists only the sub-field that changed', () {
      final comparison = buildEventDuplicateFieldComparison(
        context: null,
        current: _event(city: 'Ghent'),
        previous: _event(),
        native: _event(),
        group: EventDuplicateFieldGroup.location,
        l10n: l10n,
      );
      expect(comparison.lines.map((line) => line.label), ['City']);
      expect(comparison.lines.single.from, 'Brussels');
      expect(comparison.lines.single.to, 'Ghent');
      expect(comparison.nativeMatchesPrevious, isTrue);
    });

    test('description keeps the full text', () {
      final description = 'B' * 120;
      final comparison = buildEventDuplicateFieldComparison(
        context: null,
        current: _event(description: description),
        previous: _event(description: 'Short'),
        native: _event(description: 'Short'),
        group: EventDuplicateFieldGroup.description,
        l10n: l10n,
      );
      expect(comparison.lines.single.from, 'Short');
      expect(comparison.lines.single.to, description);
    });

    test(
      'linked spots note when the count stays the same but contents change',
      () {
        final comparison = buildEventDuplicateFieldComparison(
          context: null,
          current: _event(spotIds: const ['spot-2']),
          previous: _event(spotIds: const ['spot-1']),
          native: _event(spotIds: const ['spot-1']),
          group: EventDuplicateFieldGroup.linkedSpots,
          l10n: l10n,
        );
        expect(comparison.lines.single.contentsChanged, isTrue);
        expect(comparison.nativeMatchesPrevious, isTrue);
      },
    );
  });
}
