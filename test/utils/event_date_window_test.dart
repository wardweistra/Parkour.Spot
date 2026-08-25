import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_date_window.dart';

void main() {
  group('EventDateWindow', () {
    test('aroundEvent pads start and end by one week', () {
      final start = DateTime.utc(2026, 6, 10, 18);
      final end = DateTime.utc(2026, 6, 12, 20);
      final window = EventDateWindow.aroundEvent(startAt: start, endAt: end);

      expect(window.start, start.subtract(const Duration(days: 7)));
      expect(window.end, end.add(const Duration(days: 7)));
    });

    test('overlapsParkourEvent matches overlapping ranges', () {
      final window = EventDateWindow.aroundEvent(
        startAt: DateTime.utc(2026, 6, 10),
        endAt: DateTime.utc(2026, 6, 12),
      );

      final overlapping = ParkourEvent(
        id: 'a',
        title: 'Jam',
        startAt: DateTime.utc(2026, 6, 11),
        endAt: DateTime.utc(2026, 6, 11, 23),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final farAway = ParkourEvent(
        id: 'b',
        title: 'Later',
        startAt: DateTime.utc(2026, 8, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(window.overlapsParkourEvent(overlapping), isTrue);
      expect(window.overlapsParkourEvent(farAway), isFalse);
    });
  });

  group('compareEventsByDatetimeProximity', () {
    ParkourEvent event({
      required String id,
      required DateTime startAt,
      DateTime? endAt,
      String? eventSourceId,
    }) {
      return ParkourEvent(
        id: id,
        title: id,
        startAt: startAt,
        endAt: endAt,
        eventSourceId: eventSourceId,
      );
    }

    final referenceStart = DateTime.utc(2026, 6, 10, 18);
    final referenceEnd = DateTime.utc(2026, 6, 10, 21);

    test('closer start time ranks first', () {
      final closer = event(
        id: 'closer',
        startAt: DateTime.utc(2026, 6, 10, 19),
      );
      final farther = event(
        id: 'farther',
        startAt: DateTime.utc(2026, 6, 12, 18),
      );

      expect(
        compareEventsByDatetimeProximity(
          closer,
          farther,
          referenceStartAt: referenceStart,
        ),
        lessThan(0),
      );
    });

    test('end time is used as a tie-break when starts match', () {
      final closerEnd = event(
        id: 'closer-end',
        startAt: referenceStart,
        endAt: DateTime.utc(2026, 6, 10, 22),
      );
      final fartherEnd = event(
        id: 'farther-end',
        startAt: referenceStart,
        endAt: DateTime.utc(2026, 6, 11, 18),
      );

      expect(
        compareEventsByDatetimeProximity(
          closerEnd,
          fartherEnd,
          referenceStartAt: referenceStart,
          referenceEndAt: referenceEnd,
        ),
        lessThan(0),
      );
    });

    test('missing endAt is treated as startAt', () {
      final withEnd = event(
        id: 'with-end',
        startAt: referenceStart,
        endAt: DateTime.utc(2026, 6, 11, 18),
      );
      final withoutEnd = event(id: 'without-end', startAt: referenceStart);

      expect(
        compareEventsByDatetimeProximity(
          withoutEnd,
          withEnd,
          referenceStartAt: referenceStart,
          referenceEndAt: referenceEnd,
        ),
        lessThan(0),
      );
    });

    test('native ranks before external when datetimes match', () {
      final native = event(
        id: 'native',
        startAt: referenceStart,
        endAt: referenceEnd,
      );
      final external = event(
        id: 'external',
        startAt: referenceStart,
        endAt: referenceEnd,
        eventSourceId: 'ics-source',
      );

      expect(
        compareEventsByDatetimeProximity(
          native,
          external,
          referenceStartAt: referenceStart,
          referenceEndAt: referenceEnd,
        ),
        lessThan(0),
      );
    });

    test('sorts a mixed list closest-first', () {
      final events = [
        event(id: 'week-later', startAt: DateTime.utc(2026, 6, 16, 18)),
        event(
          id: 'external-same-time',
          startAt: referenceStart,
          endAt: referenceEnd,
          eventSourceId: 'ics',
        ),
        event(
          id: 'native-same-time',
          startAt: referenceStart,
          endAt: referenceEnd,
        ),
        event(id: 'hour-later', startAt: DateTime.utc(2026, 6, 10, 19)),
      ];

      sortEventsByDatetimeProximity(
        events,
        referenceStartAt: referenceStart,
        referenceEndAt: referenceEnd,
      );

      expect(events.map((e) => e.id).toList(), [
        'native-same-time',
        'external-same-time',
        'hour-later',
        'week-later',
      ]);
    });
  });

  group('filterEventsByDuplicateCountry', () {
    ParkourEvent event({
      required String id,
      required DateTime startAt,
      String? countryCode,
    }) {
      return ParkourEvent(
        id: id,
        title: id,
        startAt: startAt,
        countryCode: countryCode,
      );
    }

    test('excludes candidates in a different country', () {
      final sameCountry = event(
        id: 'nl',
        startAt: DateTime.utc(2026, 6, 10),
        countryCode: 'NL',
      );
      final otherCountry = event(
        id: 'be',
        startAt: DateTime.utc(2026, 6, 10),
        countryCode: 'BE',
      );

      final filtered = filterEventsByDuplicateCountry(
        [sameCountry, otherCountry],
        referenceCountryCode: 'nl',
      );

      expect(filtered.map((e) => e.id).toList(), ['nl']);
    });

    test('keeps candidates when reference country is missing', () {
      final withCountry = event(
        id: 'de',
        startAt: DateTime.utc(2026, 6, 10),
        countryCode: 'DE',
      );

      final filtered = filterEventsByDuplicateCountry(
        [withCountry],
        referenceCountryCode: null,
      );

      expect(filtered, [withCountry]);
    });

    test('keeps candidates when their country is missing', () {
      final noCountry = event(
        id: 'unknown',
        startAt: DateTime.utc(2026, 6, 10),
      );

      final filtered = filterEventsByDuplicateCountry(
        [noCountry],
        referenceCountryCode: 'NL',
      );

      expect(filtered, [noCountry]);
    });
  });
}
