import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/utils/map_bounds_utils.dart';

void main() {
  group('latLngBoundsFromPlaceViewport', () {
    test('parses a Places viewport', () {
      final bounds = latLngBoundsFromPlaceViewport({
        'northeast': {'lat': 52.43, 'lng': 5.07},
        'southwest': {'lat': 52.27, 'lng': 4.72},
      });

      expect(
        bounds,
        LatLngBounds(
          southwest: const LatLng(52.27, 4.72),
          northeast: const LatLng(52.43, 5.07),
        ),
      );
    });

    test('accepts integer coordinates', () {
      final bounds = latLngBoundsFromPlaceViewport({
        'northeast': {'lat': 54, 'lng': 8},
        'southwest': {'lat': 50, 'lng': 3},
      });

      expect(bounds?.southwest, const LatLng(50, 3));
      expect(bounds?.northeast, const LatLng(54, 8));
    });

    test('returns null for missing input or keys', () {
      expect(latLngBoundsFromPlaceViewport(null), isNull);
      expect(latLngBoundsFromPlaceViewport('viewport'), isNull);
      expect(
        latLngBoundsFromPlaceViewport({
          'northeast': {'lat': 52.43, 'lng': 5.07},
        }),
        isNull,
      );
      expect(
        latLngBoundsFromPlaceViewport({
          'northeast': {'lat': 52.43},
          'southwest': {'lat': 52.27, 'lng': 4.72},
        }),
        isNull,
      );
    });

    test('returns null for non-numeric values', () {
      expect(
        latLngBoundsFromPlaceViewport({
          'northeast': {'lat': '52.43', 'lng': 5.07},
          'southwest': {'lat': 52.27, 'lng': 4.72},
        }),
        isNull,
      );
    });

    test('returns null for a viewport crossing the antimeridian', () {
      expect(
        latLngBoundsFromPlaceViewport({
          'northeast': {'lat': -15.0, 'lng': -178.0},
          'southwest': {'lat': -21.0, 'lng': 177.0},
        }),
        isNull,
      );
    });
  });
}
