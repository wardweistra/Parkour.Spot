import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/upcoming_linked_events_utils.dart';

EventMapPin _pin({
  required String id,
  required String eventId,
  required DateTime startAt,
  String? spotId = 'spot-a',
  EventMapPinKind kind = EventMapPinKind.spot,
  String title = 'Event',
}) {
  return EventMapPin(
    id: id,
    eventId: eventId,
    kind: kind,
    latitude: 1,
    longitude: 2,
    title: title,
    startAt: startAt,
    spotId: spotId,
  );
}

void main() {
  group('dedupeAndSortSpotEventPins', () {
    test('filters to spot kind and optional spotId', () {
      final pins = [
        _pin(
          id: 'p1',
          eventId: 'e1',
          startAt: DateTime.utc(2026, 8, 1),
          title: 'Jam A',
        ),
        _pin(
          id: 'p2',
          eventId: 'e2',
          startAt: DateTime.utc(2026, 8, 2),
          spotId: 'other',
          title: 'Other spot',
        ),
        _pin(
          id: 'p3',
          eventId: 'e3',
          startAt: DateTime.utc(2026, 8, 3),
          kind: EventMapPinKind.venue,
          spotId: null,
          title: 'Venue',
        ),
      ];

      final result = dedupeAndSortSpotEventPins(pins, spotId: 'spot-a');

      expect(result, hasLength(1));
      expect(result.single.eventId, 'e1');
    });

    test('dedupes by eventId keeping earliest startAt and sorts ascending', () {
      final pins = [
        _pin(
          id: 'later',
          eventId: 'dup',
          startAt: DateTime.utc(2026, 9, 10),
          title: 'Later dup',
        ),
        _pin(
          id: 'b',
          eventId: 'b',
          startAt: DateTime.utc(2026, 9, 5),
          title: 'B',
        ),
        _pin(
          id: 'earlier',
          eventId: 'dup',
          startAt: DateTime.utc(2026, 9, 1),
          title: 'Earlier dup',
        ),
        _pin(
          id: 'a',
          eventId: 'a',
          startAt: DateTime.utc(2026, 8, 20),
          title: 'A',
        ),
      ];

      final result = dedupeAndSortSpotEventPins(pins, spotId: 'spot-a');

      expect(result.map((p) => p.eventId).toList(), ['a', 'dup', 'b']);
      expect(result[1].title, 'Earlier dup');
    });

    test('two distinct events yield moreCount of 1 for panel CTA', () {
      final pins = dedupeAndSortSpotEventPins([
        _pin(
          id: 'p1',
          eventId: 'e1',
          startAt: DateTime.utc(2026, 8, 1),
          title: 'First',
        ),
        _pin(
          id: 'p2',
          eventId: 'e2',
          startAt: DateTime.utc(2026, 8, 15),
          title: 'Second',
        ),
      ], spotId: 'spot-a');

      final events = upcomingLinkedEventsFromPins(pins);
      expect(events, hasLength(2));
      expect(events.length - 1, 1);
      expect(events.first.title, 'First');
    });
  });

  group('upcomingLinkedEventsFromParkourEvents', () {
    test('skips events without id and preserves order', () {
      final withId = ParkourEvent(
        id: 'ev-1',
        title: 'Listed',
        description: '',
        startAt: DateTime.utc(2026, 10, 1),
        endAt: DateTime.utc(2026, 10, 2),
        isDateOnly: true,
        spotIds: const [],
        spotListIds: const ['list-1'],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        createdBy: 'user',
      );
      final withoutId = ParkourEvent(
        title: 'No id',
        description: '',
        startAt: DateTime.utc(2026, 10, 5),
        endAt: DateTime.utc(2026, 10, 6),
        isDateOnly: true,
        spotIds: const [],
        spotListIds: const [],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        createdBy: 'user',
      );

      final result = upcomingLinkedEventsFromParkourEvents([withId, withoutId]);

      expect(result, hasLength(1));
      expect(result.single.id, 'ev-1');
      expect(result.single.title, 'Listed');
    });
  });

  group('isLinkedEventPast', () {
    final now = DateTime.utc(2026, 8, 19, 10);

    test('uses endAt when present so in-progress events are not past', () {
      expect(
        isLinkedEventPast(
          startAt: DateTime.utc(2026, 8, 2),
          endAt: DateTime.utc(2026, 8, 25),
          now: now,
        ),
        isFalse,
      );
      expect(
        isLinkedEventPast(
          startAt: DateTime.utc(2026, 8, 2),
          endAt: DateTime.utc(2026, 8, 8),
          now: now,
        ),
        isTrue,
      );
    });

    test('falls back to startAt when there is no endAt', () {
      expect(
        isLinkedEventPast(startAt: DateTime.utc(2026, 8, 18), now: now),
        isTrue,
      );
      expect(
        isLinkedEventPast(startAt: DateTime.utc(2026, 8, 20), now: now),
        isFalse,
      );
    });

    test('an event ending exactly now is still upcoming', () {
      expect(
        isLinkedEventPast(
          startAt: DateTime.utc(2026, 8, 18),
          endAt: now,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('partitionLinkedEvents', () {
    final now = DateTime.utc(2026, 8, 19, 10);

    UpcomingLinkedEvent event({
      required String id,
      required DateTime startAt,
      DateTime? endAt,
    }) {
      return UpcomingLinkedEvent(
        id: id,
        title: id,
        startAt: startAt,
        endAt: endAt,
      );
    }

    test('sorts upcoming earliest first and past most recent first', () {
      final result = partitionLinkedEvents([
        event(
          id: 'older-past',
          startAt: DateTime.utc(2026, 7, 1),
          endAt: DateTime.utc(2026, 7, 2),
        ),
        event(id: 'later-upcoming', startAt: DateTime.utc(2026, 9, 10)),
        event(
          id: 'recent-past',
          startAt: DateTime.utc(2026, 8, 2),
          endAt: DateTime.utc(2026, 8, 8),
        ),
        event(id: 'next-upcoming', startAt: DateTime.utc(2026, 8, 22)),
      ], now: now);

      expect(result.upcoming.map((e) => e.id).toList(), [
        'next-upcoming',
        'later-upcoming',
      ]);
      expect(result.past.map((e) => e.id).toList(), [
        'recent-past',
        'older-past',
      ]);
    });

    test('treats in-progress events as upcoming', () {
      final result = partitionLinkedEvents([
        event(
          id: 'happening',
          startAt: DateTime.utc(2026, 8, 18),
          endAt: DateTime.utc(2026, 8, 20),
        ),
      ], now: now);

      expect(result.upcoming.map((e) => e.id), ['happening']);
      expect(result.past, isEmpty);
    });
  });

  group('mergeAndPartitionLinkedEvents', () {
    final now = DateTime.utc(2026, 8, 19, 10);

    test('unions sources and prefers event documents over pins', () {
      final result = mergeAndPartitionLinkedEvents(
        fromPins: [
          UpcomingLinkedEvent(
            id: 'shared',
            title: 'From pin',
            startAt: DateTime.utc(2026, 8, 2),
            endAt: DateTime.utc(2026, 8, 8),
          ),
          UpcomingLinkedEvent(
            id: 'pin-only',
            title: 'List-linked past',
            startAt: DateTime.utc(2026, 8, 1),
            endAt: DateTime.utc(2026, 8, 3),
          ),
        ],
        fromEvents: [
          UpcomingLinkedEvent(
            id: 'shared',
            title: 'From events',
            startAt: DateTime.utc(2026, 8, 2),
            endAt: DateTime.utc(2026, 8, 8),
          ),
          UpcomingLinkedEvent(
            id: 'future',
            title: 'Direct upcoming',
            startAt: DateTime.utc(2026, 9, 1),
          ),
        ],
        now: now,
      );

      expect(result.past.map((e) => e.id).toList(), ['shared', 'pin-only']);
      expect(result.past.first.title, 'From events');
      expect(result.upcoming.map((e) => e.id).toList(), ['future']);
    });
  });

  group('linkedEventTiming', () {
    final now = DateTime.utc(2026, 8, 19, 10);

    test('classifies happening, upcoming, and past', () {
      expect(
        linkedEventTiming(
          startAt: DateTime.utc(2026, 8, 18),
          endAt: DateTime.utc(2026, 8, 20),
          now: now,
        ),
        LinkedEventTiming.happening,
      );
      expect(
        linkedEventTiming(startAt: DateTime.utc(2026, 8, 22), now: now),
        LinkedEventTiming.upcoming,
      );
      expect(
        linkedEventTiming(
          startAt: DateTime.utc(2026, 8, 2),
          endAt: DateTime.utc(2026, 8, 8),
          now: now,
        ),
        LinkedEventTiming.past,
      );
    });
  });

  group('linkedEventsMoreAction', () {
    UpcomingLinkedEvent event(String id, DateTime startAt) {
      return UpcomingLinkedEvent(id: id, title: id, startAt: startAt);
    }

    test('uses remaining count when more upcoming exist', () {
      final action = linkedEventsMoreAction(
        LinkedSpotEvents(
          upcoming: [
            event('a', DateTime.utc(2026, 9, 1)),
            event('b', DateTime.utc(2026, 9, 10)),
          ],
          past: [event('c', DateTime.utc(2026, 8, 1))],
        ),
      );
      expect(action, isNotNull);
      expect(action!.kind, LinkedEventsMoreKind.remaining);
      expect(action.count, 2);
    });

    test(
      'uses past-only count when featured is upcoming and extras are past',
      () {
        final action = linkedEventsMoreAction(
          LinkedSpotEvents(
            upcoming: [event('a', DateTime.utc(2026, 9, 1))],
            past: [
              event('c', DateTime.utc(2026, 8, 8)),
              event('d', DateTime.utc(2026, 7, 1)),
            ],
          ),
        );
        expect(action!.kind, LinkedEventsMoreKind.pastOnly);
        expect(action.count, 2);
      },
    );

    test('uses remaining count on a past-only callout', () {
      final action = linkedEventsMoreAction(
        LinkedSpotEvents(
          past: [
            event('c', DateTime.utc(2026, 8, 8)),
            event('d', DateTime.utc(2026, 7, 1)),
          ],
        ),
      );
      expect(action!.kind, LinkedEventsMoreKind.remaining);
      expect(action.count, 1);
    });

    test('hides the action when a single event is featured', () {
      expect(
        linkedEventsMoreAction(
          LinkedSpotEvents(upcoming: [event('a', DateTime.utc(2026, 9, 1))]),
        ),
        isNull,
      );
      expect(
        linkedEventsMoreAction(
          LinkedSpotEvents(past: [event('c', DateTime.utc(2026, 8, 1))]),
        ),
        isNull,
      );
    });
  });

  group('linkedEventsSheetOrder', () {
    test('orders from farthest future to oldest past', () {
      final ordered = linkedEventsSheetOrder(
        LinkedSpotEvents(
          upcoming: [
            UpcomingLinkedEvent(
              id: 'soon',
              title: 'soon',
              startAt: DateTime.utc(2026, 8, 22),
            ),
            UpcomingLinkedEvent(
              id: 'later',
              title: 'later',
              startAt: DateTime.utc(2026, 9, 10),
            ),
          ],
          past: [
            UpcomingLinkedEvent(
              id: 'recent',
              title: 'recent',
              startAt: DateTime.utc(2026, 8, 2),
              endAt: DateTime.utc(2026, 8, 8),
            ),
            UpcomingLinkedEvent(
              id: 'older',
              title: 'older',
              startAt: DateTime.utc(2026, 6, 1),
              endAt: DateTime.utc(2026, 6, 2),
            ),
          ],
        ),
      );
      expect(ordered.map((e) => e.id).toList(), [
        'later',
        'soon',
        'recent',
        'older',
      ]);
    });
  });
}
