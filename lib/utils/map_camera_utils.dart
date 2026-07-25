import 'package:google_maps_flutter/google_maps_flutter.dart';

const double _mobileMapBreakpoint = 600;
const double _selectedSpotZoom = 15;

/// Camera updates used when locating a spot from Explore.
///
/// On a narrow viewport, the final pixel scroll places the selected spot in
/// the middle of the top half of the screen so the overlay card does not hide
/// its marker.
List<CameraUpdate> selectedSpotCameraUpdates({
  required LatLng target,
  required double currentZoom,
  required double viewportWidth,
  required double viewportHeight,
}) {
  final updates = <CameraUpdate>[CameraUpdate.newLatLng(target)];

  if (currentZoom < _selectedSpotZoom) {
    updates.add(CameraUpdate.zoomTo(_selectedSpotZoom));
  }

  if (viewportWidth < _mobileMapBreakpoint) {
    updates.add(CameraUpdate.scrollBy(0, viewportHeight / 4));
  }

  return updates;
}
