import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/spot.dart';

bool spotHasCoordinates(Spot spot) =>
    spot.latitude != 0 || spot.longitude != 0;

/// Resolves coordinates used to infer an event's timezone.
///
/// Priority: explicit map pin, first linked spot, first spot-list spot.
LatLng? resolveEventTimezoneCoordinates({
  LatLng? pickedLocation,
  required List<Spot> linkedSpots,
  required List<Spot> linkedSpotListSpots,
}) {
  if (pickedLocation != null) return pickedLocation;

  for (final spot in linkedSpots) {
    if (spotHasCoordinates(spot)) {
      return LatLng(spot.latitude, spot.longitude);
    }
  }

  for (final spot in linkedSpotListSpots) {
    if (spotHasCoordinates(spot)) {
      return LatLng(spot.latitude, spot.longitude);
    }
  }

  return null;
}
