import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/utils/explore_events_utils.dart';

void main() {
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
  });
}
