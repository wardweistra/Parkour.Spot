import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/utils/event_schedule_utils.dart';
import 'package:parkour_spot/utils/explore_events_utils.dart';

EventMapPin _pin({
  required String eventId,
  required DateTime startAt,
  String? timeZone,
}) {
  return EventMapPin(
    id: '${eventId}_venue',
    eventId: eventId,
    kind: EventMapPinKind.venue,
    latitude: 1,
    longitude: 1,
    title: eventId,
    startAt: startAt,
    timeZone: timeZone,
  );
}

void main() {
  setUpAll(EventScheduleUtils.ensureTimeZonesInitialized);

  group('explore_events_utils', () {
    test('eventPinsBySpotId keeps earliest startAt per spot', () {
      final later = EventMapPin(
        id: 'e1_spot_a',
        eventId: 'e1',
        kind: EventMapPinKind.spot,
        latitude: 1,
        longitude: 1,
        title: 'Later',
        startAt: DateTime.utc(2026, 12, 2),
        spotId: 'spot-a',
      );
      final earlier = EventMapPin(
        id: 'e2_spot_a',
        eventId: 'e2',
        kind: EventMapPinKind.spot,
        latitude: 1,
        longitude: 1,
        title: 'Earlier',
        startAt: DateTime.utc(2026, 12, 1),
        spotId: 'spot-a',
      );
      final map = eventPinsBySpotId([later, earlier]);
      expect(map['spot-a']?.title, 'Earlier');
    });

    test('dedupePinsByEventId keeps one pin per event', () {
      final pins = [
        EventMapPin(
          id: 'e1_venue',
          eventId: 'e1',
          kind: EventMapPinKind.venue,
          latitude: 1,
          longitude: 1,
          title: 'Venue',
          startAt: DateTime.utc(2026, 12, 1),
        ),
        EventMapPin(
          id: 'e1_spot_x',
          eventId: 'e1',
          kind: EventMapPinKind.spot,
          latitude: 2,
          longitude: 2,
          title: 'Spot',
          startAt: DateTime.utc(2026, 12, 1),
          spotId: 'x',
        ),
      ];
      expect(dedupePinsByEventId(pins), hasLength(1));
    });

    test('dedupePinsByEventId prefers venue pin at same startAt', () {
      final start = DateTime.utc(2026, 12, 1);
      final pins = [
        EventMapPin(
          id: 'e1_spot_x',
          eventId: 'e1',
          kind: EventMapPinKind.spot,
          latitude: 2,
          longitude: 2,
          title: 'Spot',
          startAt: start,
          spotId: 'x',
        ),
        EventMapPin(
          id: 'e1_venue',
          eventId: 'e1',
          kind: EventMapPinKind.venue,
          latitude: 1,
          longitude: 1,
          title: 'Venue',
          startAt: start,
        ),
      ];
      expect(dedupePinsByEventId(pins).single.kind, EventMapPinKind.venue);
    });

    test('groupExploreEventsByMonth keeps same-month events in one group', () {
      final events = [
        _pin(eventId: 'e1', startAt: DateTime.utc(2026, 5, 10)),
        _pin(eventId: 'e2', startAt: DateTime.utc(2026, 5, 20)),
      ];

      final groups = groupExploreEventsByMonth(events);

      expect(groups, hasLength(1));
      expect(groups.single.monthStart, DateTime(2026, 5));
      expect(groups.single.events.map((e) => e.eventId), ['e1', 'e2']);
    });

    test('groupExploreEventsByMonth splits on month boundary', () {
      final events = [
        _pin(eventId: 'dec', startAt: DateTime.utc(2026, 12, 15)),
        _pin(eventId: 'jan', startAt: DateTime.utc(2027, 1, 5)),
      ];

      final groups = groupExploreEventsByMonth(events);

      expect(groups, hasLength(2));
      expect(groups[0].monthStart, DateTime(2026, 12));
      expect(groups[0].events.single.eventId, 'dec');
      expect(groups[1].monthStart, DateTime(2027, 1));
      expect(groups[1].events.single.eventId, 'jan');
    });

    test('groupExploreEventsByMonth uses event time zone for month key', () {
      // 2026-02-01T07:00Z is still 2026-01-31 in America/Los_Angeles (PST).
      final events = [
        _pin(
          eventId: 'la-jan',
          startAt: DateTime.utc(2026, 2, 1, 7),
          timeZone: 'America/Los_Angeles',
        ),
        _pin(
          eventId: 'la-feb',
          startAt: DateTime.utc(2026, 2, 15, 8),
          timeZone: 'America/Los_Angeles',
        ),
      ];

      final groups = groupExploreEventsByMonth(events);

      expect(groups, hasLength(2));
      expect(groups[0].monthStart, DateTime(2026, 1));
      expect(groups[0].events.single.eventId, 'la-jan');
      expect(groups[1].monthStart, DateTime(2026, 2));
      expect(groups[1].events.single.eventId, 'la-feb');
    });
  });
}
