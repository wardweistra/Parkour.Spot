import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/utils/event_linked_spot_loader.dart';
import 'package:parkour_spot/utils/event_locate_utils.dart';

void main() {
  group('isSpotEligibleForEventMapPin', () {
    test('accepts visible spot with coordinates', () {
      final spot = Spot(
        id: 's1',
        name: 'Spot',
        description: '',
        latitude: 52.37,
        longitude: 4.89,
      );
      expect(isSpotEligibleForEventMapPin(spot), isTrue);
    });

    test('rejects hidden, duplicate, and zero-coordinate spots', () {
      expect(
        isSpotEligibleForEventMapPin(
          Spot(
            id: 'h',
            name: 'Hidden',
            description: '',
            latitude: 1,
            longitude: 1,
            hidden: true,
          ),
        ),
        isFalse,
      );
      expect(
        isSpotEligibleForEventMapPin(
          Spot(
            id: 'd',
            name: 'Dup',
            description: '',
            latitude: 1,
            longitude: 1,
            duplicateOf: 'other',
          ),
        ),
        isFalse,
      );
      expect(
        isSpotEligibleForEventMapPin(
          Spot(
            id: 'z',
            name: 'Zero',
            description: '',
            latitude: 0,
            longitude: 0,
          ),
        ),
        isFalse,
      );
    });
  });

  group('isSpotListExpandableForEventPins', () {
    SpotList listWith(SpotListVisibility visibility) {
      final now = DateTime.utc(2026, 1, 1);
      return SpotList(
        id: 'list-1',
        name: 'List',
        spotIds: const [],
        createdBy: 'user',
        createdAt: now,
        updatedAt: now,
        visibility: visibility,
      );
    }

    test('allows public and unlisted', () {
      expect(
        isSpotListExpandableForEventPins(listWith(SpotListVisibility.public)),
        isTrue,
      );
      expect(
        isSpotListExpandableForEventPins(listWith(SpotListVisibility.unlisted)),
        isTrue,
      );
    });

    test('rejects private', () {
      expect(
        isSpotListExpandableForEventPins(listWith(SpotListVisibility.private)),
        isFalse,
      );
    });
  });

  group('pickRepresentativePinForLocate', () {
    test('prefers venue over spot at same startAt', () {
      final start = DateTime.utc(2026, 7, 1);
      final pins = [
        EventMapPin(
          id: 'e1_spot_a',
          eventId: 'e1',
          kind: EventMapPinKind.spot,
          latitude: 2,
          longitude: 2,
          title: 'Spot',
          startAt: start,
          spotId: 'a',
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

      final picked = pickRepresentativePinForLocate(pins);
      expect(picked?.kind, EventMapPinKind.venue);
      expect(picked?.latitude, 1);
    });

    test('returns null for empty list', () {
      expect(pickRepresentativePinForLocate(const []), isNull);
    });
  });

  group('eventMapPinFromLinkedSpot', () {
    test('builds spot pin from event and linked spot', () {
      final event = ParkourEvent(
        id: 'event-1',
        title: 'Jam',
        startAt: DateTime.utc(2026, 8, 1, 12),
        description: 'Desc',
        imageUrls: const ['https://example.com/a.jpg'],
        city: 'Amsterdam',
        countryCode: 'nl',
        spotIds: const ['spot-1'],
      );
      final spot = Spot(
        id: 'spot-1',
        name: 'Rail',
        description: '',
        latitude: 52.37,
        longitude: 4.89,
        city: 'Ignored',
        countryCode: 'US',
      );

      final pin = eventMapPinFromLinkedSpot(event: event, spot: spot);
      expect(pin.id, 'event-1_spot_spot-1');
      expect(pin.eventId, 'event-1');
      expect(pin.kind, EventMapPinKind.spot);
      expect(pin.spotId, 'spot-1');
      expect(pin.latitude, 52.37);
      expect(pin.longitude, 4.89);
      expect(pin.title, 'Jam');
      expect(pin.city, 'Amsterdam');
      expect(pin.countryCode, 'NL');
    });

    test('inherits city/country from spot when event lacks them', () {
      final event = ParkourEvent(
        id: 'event-2',
        title: 'Session',
        startAt: DateTime.utc(2026, 8, 1),
        spotIds: const ['spot-2'],
      );
      final spot = Spot(
        id: 'spot-2',
        name: 'Wall',
        description: '',
        latitude: 48.85,
        longitude: 2.35,
        city: 'Paris',
        countryCode: 'fr',
      );

      final pin = eventMapPinFromLinkedSpot(event: event, spot: spot);
      expect(pin.city, 'Paris');
      expect(pin.countryCode, 'FR');
    });
  });

  group('resolveEventMapPinForLocate', () {
    final start = DateTime.utc(2026, 9, 1, 10);

    test('uses direct event coordinates when present', () async {
      final event = ParkourEvent(
        id: 'e-direct',
        title: 'Direct',
        startAt: start,
        latitude: 52.1,
        longitude: 5.1,
        spotIds: const ['spot-ignored'],
      );

      var pinsQueried = false;
      var linkedLoaded = false;
      final pin = await resolveEventMapPinForLocate(
        event: event,
        getMapPinsForEvent: (_) async {
          pinsQueried = true;
          return const [];
        },
        loadEligibleLinkedSpot: ({required spotIds, required spotListIds}) async {
          linkedLoaded = true;
          return null;
        },
      );

      expect(pin?.latitude, 52.1);
      expect(pin?.longitude, 5.1);
      expect(pinsQueried, isFalse);
      expect(linkedLoaded, isFalse);
    });

    test('uses representative materialized pin when no direct coords', () async {
      final event = ParkourEvent(
        id: 'e-pins',
        title: 'Pinned',
        startAt: start,
        spotIds: const ['spot-a'],
      );
      final pins = [
        EventMapPin(
          id: 'e-pins_spot_a',
          eventId: 'e-pins',
          kind: EventMapPinKind.spot,
          latitude: 40.0,
          longitude: -74.0,
          title: 'Pinned',
          startAt: start,
          spotId: 'spot-a',
        ),
        EventMapPin(
          id: 'e-pins_venue',
          eventId: 'e-pins',
          kind: EventMapPinKind.venue,
          latitude: 41.0,
          longitude: -73.0,
          title: 'Pinned',
          startAt: start,
        ),
      ];

      var linkedLoaded = false;
      final pin = await resolveEventMapPinForLocate(
        event: event,
        getMapPinsForEvent: (_) async => pins,
        loadEligibleLinkedSpot: ({required spotIds, required spotListIds}) async {
          linkedLoaded = true;
          return null;
        },
      );

      expect(pin?.kind, EventMapPinKind.venue);
      expect(pin?.latitude, 41.0);
      expect(linkedLoaded, isFalse);
    });

    test('falls back to first eligible linked spot', () async {
      final event = ParkourEvent(
        id: 'e-linked',
        title: 'Linked only',
        startAt: start,
        spotIds: const ['spot-b'],
      );
      final linked = Spot(
        id: 'spot-b',
        name: 'Linked spot',
        description: '',
        latitude: 48.85,
        longitude: 2.35,
        city: 'Paris',
        countryCode: 'FR',
      );

      final pin = await resolveEventMapPinForLocate(
        event: event,
        getMapPinsForEvent: (_) async => const [],
        loadEligibleLinkedSpot: ({required spotIds, required spotListIds}) async {
          expect(spotIds, ['spot-b']);
          return linked;
        },
      );

      expect(pin?.kind, EventMapPinKind.spot);
      expect(pin?.spotId, 'spot-b');
      expect(pin?.latitude, 48.85);
      expect(pin?.longitude, 2.35);
      expect(pin?.city, 'Paris');
    });

    test('returns null when nothing is locatable', () async {
      final event = ParkourEvent(
        id: 'e-empty',
        title: 'Nowhere',
        startAt: start,
      );

      final pin = await resolveEventMapPinForLocate(
        event: event,
        getMapPinsForEvent: (_) async => const [],
        loadEligibleLinkedSpot: ({required spotIds, required spotListIds}) async {
          return null;
        },
      );

      expect(pin, isNull);
    });
  });
}
