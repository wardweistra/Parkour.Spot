import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/models/parkour_event.dart';

void main() {
  group('EventMapPin.fromParkourEvent', () {
    test('builds venue pin from event with direct coordinates', () {
      final event = ParkourEvent(
        id: 'event-1',
        title: 'City Jam',
        startAt: DateTime.utc(2026, 6, 1, 12),
        latitude: 52.37,
        longitude: 4.89,
        address: 'Amsterdam',
        countryCode: 'NL',
      );

      final pin = EventMapPin.fromParkourEvent(event);

      expect(pin.eventId, 'event-1');
      expect(pin.kind, EventMapPinKind.venue);
      expect(pin.latitude, 52.37);
      expect(pin.longitude, 4.89);
      expect(pin.title, 'City Jam');
      expect(pin.countryCode, 'NL');
    });

    test('uses spot kind when event links spots', () {
      final event = ParkourEvent(
        id: 'event-2',
        title: 'Spot Session',
        startAt: DateTime.utc(2026, 6, 1, 12),
        latitude: 48.85,
        longitude: 2.35,
        spotIds: const ['spot-a'],
      );

      final pin = EventMapPin.fromParkourEvent(event);

      expect(pin.kind, EventMapPinKind.spot);
      expect(pin.spotId, 'spot-a');
    });

    test('throws when coordinates are missing', () {
      final event = ParkourEvent(
        id: 'event-3',
        title: 'No coords',
        startAt: DateTime.utc(2026, 6, 1, 12),
        address: 'Somewhere',
      );

      expect(
        () => EventMapPin.fromParkourEvent(event),
        throwsArgumentError,
      );
    });
  });
}
