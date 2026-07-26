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

      final result = upcomingLinkedEventsFromParkourEvents([
        withId,
        withoutId,
      ]);

      expect(result, hasLength(1));
      expect(result.single.id, 'ev-1');
      expect(result.single.title, 'Listed');
    });
  });
}
