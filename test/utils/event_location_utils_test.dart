import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/event_location_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('prefers picked location over linked spots', () {
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

    test('uses first spot-list spot when no picked location or linked spots', () {
      expect(
        resolveEventTimezoneCoordinates(
          pickedLocation: null,
          linkedSpots: const [],
          linkedSpotListSpots: [listSpot],
        ),
        const LatLng(48.8566, 2.3522),
      );
    });

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
}
