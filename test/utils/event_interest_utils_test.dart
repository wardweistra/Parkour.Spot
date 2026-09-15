import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_interest.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_interest_utils.dart';

ParkourEvent event({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
  String title = 'Jam',
}) {
  return ParkourEvent(id: id, title: title, startAt: startAt, endAt: endAt);
}

EventInterest interest({
  required String eventId,
  EventInterestStatus status = EventInterestStatus.going,
}) {
  return EventInterest(eventId: eventId, userId: 'user-1', status: status);
}

void main() {
  group('nextEventInterestStatus', () {
    test('selects a new status', () {
      expect(
        nextEventInterestStatus(null, EventInterestStatus.going),
        EventInterestStatus.going,
      );
      expect(
        nextEventInterestStatus(
          EventInterestStatus.going,
          EventInterestStatus.interested,
        ),
        EventInterestStatus.interested,
      );
    });

    test('clears when tapping the current status', () {
      expect(
        nextEventInterestStatus(
          EventInterestStatus.going,
          EventInterestStatus.going,
        ),
        isNull,
      );
    });
  });

  group('eventInterestStatsAfterChange', () {
    test('increments on first RSVP', () {
      final next = eventInterestStatsAfterChange(
        stats: EventInterestStats.empty,
        from: null,
        to: EventInterestStatus.going,
      );
      expect(next.goingCount, 1);
      expect(next.interestedCount, 0);
    });

    test('moves counts when switching status', () {
      final next = eventInterestStatsAfterChange(
        stats: const EventInterestStats(goingCount: 2, interestedCount: 5),
        from: EventInterestStatus.going,
        to: EventInterestStatus.interested,
      );
      expect(next.goingCount, 1);
      expect(next.interestedCount, 6);
    });

    test('clamps at zero when clearing', () {
      final next = eventInterestStatsAfterChange(
        stats: EventInterestStats.empty,
        from: EventInterestStatus.interested,
        to: null,
      );
      expect(next.goingCount, 0);
      expect(next.interestedCount, 0);
    });
  });

  group('isParkourEventPast', () {
    test('uses endAt when present', () {
      final jam = event(
        id: 'a',
        startAt: DateTime.utc(2026, 8, 1, 10),
        endAt: DateTime.utc(2026, 8, 1, 18),
      );
      expect(
        isParkourEventPast(jam, now: DateTime.utc(2026, 8, 1, 17)),
        isFalse,
      );
      expect(
        isParkourEventPast(jam, now: DateTime.utc(2026, 8, 1, 19)),
        isTrue,
      );
    });

    test('falls back to startAt', () {
      final jam = event(id: 'b', startAt: DateTime.utc(2026, 8, 1, 10));
      expect(
        isParkourEventPast(jam, now: DateTime.utc(2026, 8, 1, 9)),
        isFalse,
      );
      expect(
        isParkourEventPast(jam, now: DateTime.utc(2026, 8, 1, 11)),
        isTrue,
      );
    });
  });

  group('canonicalEventInterestEventId', () {
    test('uses duplicateOf when set', () {
      expect(
        canonicalEventInterestEventId(
          event(id: 'dup', startAt: DateTime.utc(2026, 9, 1)),
        ),
        'dup',
      );
      expect(
        canonicalEventInterestEventId(
          ParkourEvent(
            id: 'dup',
            title: 'Jam',
            startAt: DateTime.utc(2026, 9, 1),
            duplicateOf: ' native ',
          ),
        ),
        'native',
      );
    });
  });

  group('eventInterestWriteEventId', () {
    test('uses the listing id even when duplicateOf is set', () {
      expect(
        eventInterestWriteEventId(
          ParkourEvent(
            id: 'dup',
            title: 'Jam',
            startAt: DateTime.utc(2026, 9, 1),
            duplicateOf: 'native',
          ),
        ),
        'dup',
      );
    });
  });

  group('eventInterestClusterIds', () {
    test('includes listing, duplicateOf, and extra ids', () {
      expect(
        eventInterestClusterIds(
          event: ParkourEvent(
            id: 'dup',
            title: 'Jam',
            startAt: DateTime.utc(2026, 9, 1),
            duplicateOf: ' native ',
          ),
          extraIds: const ['sibling', ' native ', ''],
        ),
        {'dup', 'native', 'sibling'},
      );
    });
  });

  group('clusterEventInterestStatus', () {
    test('prefers Going when the user marked both', () {
      expect(
        clusterEventInterestStatus([
          interest(eventId: 'dup', status: EventInterestStatus.interested),
          interest(eventId: 'native'),
        ]),
        EventInterestStatus.going,
      );
    });

    test('returns Interested when that is the only status', () {
      expect(
        clusterEventInterestStatus([
          interest(eventId: 'dup', status: EventInterestStatus.interested),
        ]),
        EventInterestStatus.interested,
      );
    });

    test('returns null when empty', () {
      expect(clusterEventInterestStatus(const []), isNull);
    });
  });

  group('eventInterestIdsToDelete', () {
    test('clears every cluster doc including the listing', () {
      expect(
        eventInterestIdsToDelete(
          listingEventId: 'dup',
          clusterEventIds: const ['native', 'sibling', 'dup'],
          nextStatus: null,
        ),
        {'dup', 'native', 'sibling'},
      );
    });

    test('keeps the listing and deletes siblings when setting a status', () {
      expect(
        eventInterestIdsToDelete(
          listingEventId: 'dup',
          clusterEventIds: const ['native', 'sibling', 'dup'],
          nextStatus: EventInterestStatus.going,
        ),
        {'native', 'sibling'},
      );
    });
  });

  group('missingNativeEventIds', () {
    test('returns duplicateOf ids that are not already loaded', () {
      expect(
        missingNativeEventIds({
          'dup': ParkourEvent(
            id: 'dup',
            title: 'Imported',
            startAt: DateTime.utc(2026, 9, 1),
            duplicateOf: 'native',
          ),
          'other': event(id: 'other', startAt: DateTime.utc(2026, 9, 2)),
        }),
        {'native'},
      );
    });
  });

  group('partitionMyEvents', () {
    test('skips interests whose events are missing', () {
      final partition = partitionMyEvents(
        [interest(eventId: 'missing'), interest(eventId: 'keep')],
        {'keep': event(id: 'keep', startAt: DateTime.utc(2026, 9, 1))},
        now: DateTime.utc(2026, 8, 31),
      );
      expect(partition.upcoming, hasLength(1));
      expect(partition.upcoming.single.event.id, 'keep');
      expect(partition.past, isEmpty);
    });

    test('splits upcoming and past and sorts them', () {
      final later = event(
        id: 'later',
        title: 'Later jam',
        startAt: DateTime.utc(2026, 10, 2),
      );
      final sooner = event(
        id: 'sooner',
        title: 'Sooner jam',
        startAt: DateTime.utc(2026, 10, 1),
      );
      final oldB = event(
        id: 'old-b',
        title: 'B past',
        startAt: DateTime.utc(2026, 1, 2),
      );
      final oldA = event(
        id: 'old-a',
        title: 'A past',
        startAt: DateTime.utc(2026, 1, 1),
      );

      final partition = partitionMyEvents(
        [
          interest(eventId: 'later', status: EventInterestStatus.interested),
          interest(eventId: 'sooner'),
          interest(eventId: 'old-b'),
          interest(eventId: 'old-a'),
        ],
        {'later': later, 'sooner': sooner, 'old-b': oldB, 'old-a': oldA},
        now: DateTime.utc(2026, 8, 31),
      );

      expect(partition.upcoming.map((e) => e.event.id).toList(), [
        'sooner',
        'later',
      ]);
      expect(partition.past.map((e) => e.event.id).toList(), [
        'old-b',
        'old-a',
      ]);
      expect(
        partition.upcoming.first.interest.status,
        EventInterestStatus.going,
      );
    });

    test('remaps a duplicate listing to the native event', () {
      final native = event(
        id: 'native',
        title: 'Native jam',
        startAt: DateTime.utc(2026, 10, 1),
      );
      final dup = ParkourEvent(
        id: 'dup',
        title: 'Imported jam',
        startAt: DateTime.utc(2026, 10, 1),
        duplicateOf: 'native',
      );

      final partition = partitionMyEvents(
        [interest(eventId: 'dup')],
        {'dup': dup, 'native': native},
        now: DateTime.utc(2026, 8, 31),
      );

      expect(partition.upcoming, hasLength(1));
      expect(partition.upcoming.single.event.id, 'native');
      expect(partition.upcoming.single.event.title, 'Native jam');
    });

    test('keeps the duplicate when the native event is missing', () {
      final dup = ParkourEvent(
        id: 'dup',
        title: 'Imported jam',
        startAt: DateTime.utc(2026, 10, 1),
        duplicateOf: 'native',
      );

      final partition = partitionMyEvents(
        [interest(eventId: 'dup')],
        {'dup': dup},
        now: DateTime.utc(2026, 8, 31),
      );

      expect(partition.upcoming, hasLength(1));
      expect(partition.upcoming.single.event.id, 'dup');
    });

    test('dedupes native and duplicate RSVPs with Going winning', () {
      final native = event(
        id: 'native',
        title: 'Native jam',
        startAt: DateTime.utc(2026, 10, 1),
      );
      final dup = ParkourEvent(
        id: 'dup',
        title: 'Imported jam',
        startAt: DateTime.utc(2026, 10, 1),
        duplicateOf: 'native',
      );

      final partition = partitionMyEvents(
        [
          interest(eventId: 'native', status: EventInterestStatus.interested),
          interest(eventId: 'dup'),
        ],
        {'dup': dup, 'native': native},
        now: DateTime.utc(2026, 8, 31),
      );

      expect(partition.upcoming, hasLength(1));
      expect(partition.upcoming.single.event.id, 'native');
      expect(
        partition.upcoming.single.interest.status,
        EventInterestStatus.going,
      );
    });
  });
}
