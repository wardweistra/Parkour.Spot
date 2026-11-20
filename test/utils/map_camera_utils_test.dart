import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/utils/map_camera_utils.dart';

void main() {
  group('selectedSpotCameraUpdate', () {
    const target = LatLng(48.6271, 2.4311);

    test('zooms in and places the spot in the top half on mobile', () {
      final update = selectedSpotCameraUpdate(
        target: target,
        currentZoom: 3,
        viewportWidth: 390,
        viewportHeight: 667,
      );

      final (center, zoom) = _latLngZoom(update);
      expect(zoom, 15);
      expect(center.longitude, target.longitude);
      // Camera centre sits south of the spot, so the spot shows above it.
      expect(center.latitude, lessThan(target.latitude));
      expect(
        center.latitude,
        closeTo(
          offsetLatLngByPixels(target, zoom: 15, dy: 667 / 4).latitude,
          1e-12,
        ),
      );
    });

    test('keeps the spot centered on wider screens', () {
      final update = selectedSpotCameraUpdate(
        target: target,
        currentZoom: 12,
        viewportWidth: 900,
        viewportHeight: 700,
      );

      final (center, zoom) = _latLngZoom(update);
      expect(center, target);
      expect(zoom, 15);
    });

    test('never zooms out', () {
      final update = selectedSpotCameraUpdate(
        target: target,
        currentZoom: 18,
        viewportWidth: 900,
        viewportHeight: 700,
      );

      expect(_latLngZoom(update).$2, 18);
    });
  });

  group('focusCameraUpdate', () {
    test('pans and zooms in a single update', () {
      const target = LatLng(52.09, 5.12);
      final (center, zoom) = _latLngZoom(
        focusCameraUpdate(target: target, currentZoom: 4),
      );
      expect(center, target);
      expect(zoom, 15);
    });
  });

  group('offsetLatLngByPixels', () {
    test('moves by the expected distance at the equator', () {
      // At zoom 0 the world is 256 px tall; at the equator, 1 px of
      // Mercator y is about 360/256 degrees of latitude for small offsets.
      final moved = offsetLatLngByPixels(
        const LatLng(0, 10),
        zoom: 10,
        dy: 256,
      );
      expect(moved.longitude, 10);
      expect(moved.latitude, closeTo(-360 / 1024, 1e-4));
    });

    test('is the inverse of the opposite offset', () {
      const start = LatLng(52.09, 5.12);
      final there = offsetLatLngByPixels(start, zoom: 15, dy: 200);
      final back = offsetLatLngByPixels(there, zoom: 15, dy: -200);
      expect(back.latitude, closeTo(start.latitude, 1e-9));
    });
  });
}

(LatLng, double) _latLngZoom(CameraUpdate update) {
  final json = update.toJson() as List<Object?>;
  expect(json.first, 'newLatLngZoom');
  final latLng = LatLng.fromJson(json[1])!;
  return (latLng, (json[2] as num).toDouble());
}
