import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/map_bounds_utils.dart';

Spot _spot(double lat, double lng) => Spot(
      name: 'Spot',
      description: '',
      latitude: lat,
      longitude: lng,
    );

void main() {
  group('calculateBoundsForLatLngs', () {
    test('returns null for empty iterable', () {
      expect(calculateBoundsForLatLngs(const []), isNull);
    });

    test('matches calculateBoundsForSpots for equivalent coordinates', () {
      final spots = [_spot(52.0, 4.5), _spot(53.0, 5.5)];
      final fromSpots = calculateBoundsForSpots(spots);
      final fromLatLngs = calculateBoundsForLatLngs(
        spots.map((spot) => LatLng(spot.latitude, spot.longitude)),
      );
      expect(fromLatLngs, isNotNull);
      expect(fromLatLngs!.southwest.latitude, fromSpots!.southwest.latitude);
      expect(fromLatLngs.northeast.longitude, fromSpots.northeast.longitude);
    });
  });

  group('calculateBoundsForSpots', () {
    test('returns null for empty list', () {
      expect(calculateBoundsForSpots([]), isNull);
    });

    test('returns bounds with margin for single spot', () {
      final spots = [_spot(52.0, 4.5)];
      final bounds = calculateBoundsForSpots(spots);
      expect(bounds, isNotNull);
      // Same location: uses 0.01 fixed margin
      expect(bounds!.southwest.latitude, closeTo(51.99, 0.001));
      expect(bounds.southwest.longitude, closeTo(4.49, 0.001));
      expect(bounds.northeast.latitude, closeTo(52.01, 0.001));
      expect(bounds.northeast.longitude, closeTo(4.51, 0.001));
    });

    test('returns bounds with 5% margin for multiple spots', () {
      final spots = [
        _spot(50.0, 4.0),
        _spot(52.0, 6.0),
      ];
      final bounds = calculateBoundsForSpots(spots);
      expect(bounds, isNotNull);
      // Lat range 2.0, margin 0.1 each side
      expect(bounds!.southwest.latitude, closeTo(49.9, 0.01));
      expect(bounds.northeast.latitude, closeTo(52.1, 0.01));
      // Lng range 2.0, margin 0.1 each side
      expect(bounds.southwest.longitude, closeTo(3.9, 0.01));
      expect(bounds.northeast.longitude, closeTo(6.1, 0.01));
    });

    test('handles all spots at same location with fixed margin', () {
      final spots = [
        _spot(51.5, 4.9),
        _spot(51.5, 4.9),
      ];
      final bounds = calculateBoundsForSpots(spots);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, closeTo(51.49, 0.001));
      expect(bounds.northeast.latitude, closeTo(51.51, 0.001));
      expect(bounds.southwest.longitude, closeTo(4.89, 0.001));
      expect(bounds.northeast.longitude, closeTo(4.91, 0.001));
    });
  });
}
