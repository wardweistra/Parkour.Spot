import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/utils/map_camera_utils.dart';

void main() {
  group('selectedSpotCameraUpdates', () {
    const target = LatLng(48.6271, 2.4311);

    test(
      'places a selected entity in the middle of the top half on mobile',
      () {
        final updates = selectedSpotCameraUpdates(
          target: target,
          currentZoom: 12,
          viewportWidth: 390,
          viewportHeight: 667,
        );

        expect(updates.map(_type), ['newLatLng', 'zoomTo', 'scrollBy']);

        final scroll = updates.last.toJson() as List<Object>;
        expect(scroll[1], 0);
        expect(scroll[2], closeTo(667 / 4, 0.001));
      },
    );

    test('keeps the selected entity centered on wider screens', () {
      final updates = selectedSpotCameraUpdates(
        target: target,
        currentZoom: 15,
        viewportWidth: 900,
        viewportHeight: 700,
      );

      expect(updates.map(_type), ['newLatLng']);
    });

    test('applies the mobile offset after any zoom animation', () {
      final updates = selectedSpotCameraUpdates(
        target: target,
        currentZoom: 10,
        viewportWidth: 599,
        viewportHeight: 800,
      );

      expect(_type(updates.last), 'scrollBy');
    });
  });
}

String _type(CameraUpdate update) =>
    (update.toJson() as List<Object>).first as String;
