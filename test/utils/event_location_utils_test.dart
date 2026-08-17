import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/event_location_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collapseEventWhere', () {
    final linkedSpot = Spot(
      id: 'spot-1',
      name: 'Linked',
      description: '',
      latitude: 40.7128,
      longitude: -74.006,
    );
    const pin = LatLng(52.37, 4.89);

    test('prefers list over spots and pin', () {
      final collapsed = collapseEventWhere(
        pin: pin,
        spots: [linkedSpot],
        spotListIds: const ['list-1'],
      );
      expect(collapsed.kind, EventWhereKind.list);
      expect(collapsed.spotListIds, ['list-1']);
      expect(collapsed.spots, isEmpty);
      expect(collapsed.pin, isNull);
    });

    test('prefers spots over pin', () {
      final collapsed = collapseEventWhere(pin: pin, spots: [linkedSpot]);
      expect(collapsed.kind, EventWhereKind.spots);
      expect(collapsed.spots, [linkedSpot]);
      expect(collapsed.pin, isNull);
      expect(collapsed.spotListIds, isEmpty);
    });

    test('keeps pin when there are no spots or lists', () {
      final collapsed = collapseEventWhere(pin: pin);
      expect(collapsed.kind, EventWhereKind.pin);
      expect(collapsed.pin, pin);
      expect(collapsed.spots, isEmpty);
      expect(collapsed.spotListIds, isEmpty);
    });

    test('returns none when empty', () {
      final collapsed = collapseEventWhere();
      expect(collapsed.kind, EventWhereKind.none);
      expect(collapsed.pin, isNull);
      expect(collapsed.spots, isEmpty);
      expect(collapsed.spotListIds, isEmpty);
    });

    test('create-from-spot combo collapses to spots', () {
      final collapsed = collapseEventWhere(
        pin: pin,
        spots: [linkedSpot],
        spotListIds: const [],
      );
      expect(collapsed.kind, EventWhereKind.spots);
      expect(collapsed.spots.single.id, 'spot-1');
      expect(collapsed.pin, isNull);
    });

    test('ignores blank list ids', () {
      final collapsed = collapseEventWhere(
        pin: pin,
        spotListIds: const ['', '  '],
      );
      expect(collapsed.kind, EventWhereKind.pin);
      expect(collapsed.pin, pin);
    });
  });

  group('spotHasCoordinates', () {
    test('returns true when latitude is non-zero', () {
      final spot = Spot(
        name: 'Spot',
        description: '',
        latitude: 52.37,
        longitude: 0,
      );
      expect(spotHasCoordinates(spot), isTrue);
    });

    test('returns true when longitude is non-zero', () {
      final spot = Spot(
        name: 'Spot',
        description: '',
        latitude: 0,
        longitude: 4.89,
      );
      expect(spotHasCoordinates(spot), isTrue);
    });

    test('returns false when both coordinates are zero', () {
      final spot = Spot(
        name: 'Spot',
        description: '',
        latitude: 0,
        longitude: 0,
      );
      expect(spotHasCoordinates(spot), isFalse);
    });
  });

  group('resolveEventWherePickerCenter', () {
    const pin = LatLng(52.37, 4.89);
    const gps = LatLng(50.85, 4.35);
    const evry = LatLng(48.629828, 2.441782);

    test('prefers the selected pin over GPS', () {
      expect(resolveEventWherePickerCenter(pin: pin, gps: gps), pin);
    });

    test('uses GPS when no pin is selected', () {
      expect(resolveEventWherePickerCenter(pin: null, gps: gps), gps);
    });

    test('returns null when neither pin nor GPS is set', () {
      expect(resolveEventWherePickerCenter(pin: null, gps: null), isNull);
    });

    test('does not use the app default when GPS is known', () {
      expect(resolveEventWherePickerCenter(pin: null, gps: gps) ?? evry, gps);
    });
  });

  group('resolveEventTimezoneCoordinates', () {
    final linkedSpot = Spot(
      id: 'spot-1',
      name: 'Linked',
      description: '',
      latitude: 40.7128,
      longitude: -74.006,
    );
    final listSpot = Spot(
      id: 'spot-2',
      name: 'List spot',
      description: '',
      latitude: 48.8566,
      longitude: 2.3522,
    );

    test('prefers picked location over linked spots before collapse', () {
      final picked = const LatLng(52.37, 4.89);
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: picked,
          linkedSpots: [linkedSpot],
          linkedSpotListSpots: [listSpot],
        ),
        picked,
      );
    });

    test('after collapse, timezone uses spots instead of the dropped pin', () {
      final collapsed = collapseEventWhere(
        pin: const LatLng(52.37, 4.89),
        spots: [linkedSpot],
      );
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: collapsed.pin,
          linkedSpots: collapsed.spots,
          linkedSpotListSpots: const [],
        ),
        const LatLng(40.7128, -74.006),
      );
    });

    test('uses first linked spot when no picked location', () {
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: null,
          linkedSpots: [linkedSpot],
          linkedSpotListSpots: [listSpot],
        ),
        const LatLng(40.7128, -74.006),
      );
    });

    test(
      'uses first spot-list spot when no picked location or linked spots',
      () {
        expect(
          resolveEventTimezoneCoordinates(
            pickedLocation: null,
            linkedSpots: const [],
            linkedSpotListSpots: [listSpot],
          ),
          const LatLng(48.8566, 2.3522),
        );
      },
    );

    test('returns null when no coordinates are available', () {
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: null,
          linkedSpots: const [],
          linkedSpotListSpots: const [],
        ),
        isNull,
      );
    });

    test('skips linked spots without coordinates', () {
      final spotWithoutCoords = Spot(
        id: 'empty',
        name: 'Empty',
        description: '',
        latitude: 0,
        longitude: 0,
      );
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: null,
          linkedSpots: [spotWithoutCoords, linkedSpot],
          linkedSpotListSpots: const [],
        ),
        const LatLng(40.7128, -74.006),
      );
    });
  });

  group('eventHasDirectLocation', () {
    test('returns true when coordinates are set', () {
      expect(eventHasDirectLocation(latitude: 52.0, longitude: 4.0), isTrue);
    });

    test('returns true when address is set', () {
      expect(eventHasDirectLocation(address: 'Main Street 1'), isTrue);
    });

    test('returns false when only linked spots provide location', () {
      expect(eventHasDirectLocation(), isFalse);
    });
  });

  group('resolveEventCityCountryFromLinkedSpots', () {
    final linkedSpot = Spot(
      id: 'spot-1',
      name: 'Linked',
      description: '',
      latitude: 40.7128,
      longitude: -74.006,
      city: 'New York',
      countryCode: 'US',
    );

    test(
      'inherits city and country from linked spot when no direct location',
      () {
        final resolved = resolveEventCityCountryFromLinkedSpots(
          latitude: null,
          longitude: null,
          address: null,
          linkedSpots: [linkedSpot],
          linkedSpotListSpots: const [],
        );
        expect(resolved.city, 'New York');
        expect(resolved.countryCode, 'US');
      },
    );

    test('does not inherit when event has direct location', () {
      final resolved = resolveEventCityCountryFromLinkedSpots(
        latitude: 52.37,
        longitude: 4.89,
        address: 'Utrecht',
        linkedSpots: [linkedSpot],
        linkedSpotListSpots: const [],
      );
      expect(resolved.city, isNull);
      expect(resolved.countryCode, isNull);
    });

    test('keeps existing city/country and fills missing values from spot', () {
      final resolved = resolveEventCityCountryFromLinkedSpots(
        latitude: null,
        longitude: null,
        address: null,
        city: 'Rotterdam',
        linkedSpots: [linkedSpot],
        linkedSpotListSpots: const [],
      );
      expect(resolved.city, 'Rotterdam');
      expect(resolved.countryCode, 'US');
    });
  });
}
