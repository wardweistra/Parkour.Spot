import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

const double _mobileMapBreakpoint = 600;
const double _selectedSpotZoom = 15;

/// Google Maps world width in logical pixels at zoom 0.
const double _tileSize = 256;

/// Camera update used when locating a spot from Explore.
///
/// Zooms in to at least street level (never out). On a narrow viewport the
/// selected spot is placed in the middle of the top half of the screen so the
/// overlay card does not hide its marker.
///
/// This is a single update on purpose: on Android, `animateCamera` completes
/// as soon as the animation starts, so a chain of updates cancels all but the
/// last one.
CameraUpdate selectedSpotCameraUpdate({
  required LatLng target,
  required double currentZoom,
  required double viewportWidth,
  required double viewportHeight,
}) {
  final zoom = math.max(currentZoom, _selectedSpotZoom);
  final center = viewportWidth < _mobileMapBreakpoint
      ? offsetLatLngByPixels(target, zoom: zoom, dy: viewportHeight / 4)
      : target;
  return CameraUpdate.newLatLngZoom(center, zoom);
}

/// Pans to [target] and zooms in to at least [minZoom] in one camera update.
///
/// Use instead of `newLatLng` followed by `zoomTo`, which on Android cancels
/// the pan (see [selectedSpotCameraUpdate]).
CameraUpdate focusCameraUpdate({
  required LatLng target,
  required double currentZoom,
  double minZoom = _selectedSpotZoom,
}) {
  return CameraUpdate.newLatLngZoom(target, math.max(currentZoom, minZoom));
}

/// Returns the point [dy] logical pixels south of [point] at [zoom]
/// (Web Mercator), i.e. where the camera centre goes after
/// `CameraUpdate.scrollBy(0, dy)` from [point].
LatLng offsetLatLngByPixels(
  LatLng point, {
  required double zoom,
  required double dy,
}) {
  final worldSize = _tileSize * math.pow(2, zoom);
  final sinLat = math.sin(point.latitude * math.pi / 180);
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * worldSize;
  final n = math.pi * (1 - 2 * (y + dy) / worldSize);
  final latitude = 180 / math.pi * math.atan(_sinh(n));
  return LatLng(latitude, point.longitude);
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
