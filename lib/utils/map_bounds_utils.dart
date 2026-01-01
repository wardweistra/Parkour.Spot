import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/spot.dart';

/// Calculate bounds to fit all spots with 5% margin
/// Returns null if the spots list is empty
LatLngBounds? calculateBoundsForSpots(List<Spot> spots) {
  if (spots.isEmpty) return null;

  double minLat = spots.first.latitude;
  double maxLat = spots.first.latitude;
  double minLng = spots.first.longitude;
  double maxLng = spots.first.longitude;

  for (final spot in spots) {
    if (spot.latitude < minLat) minLat = spot.latitude;
    if (spot.latitude > maxLat) maxLat = spot.latitude;
    if (spot.longitude < minLng) minLng = spot.longitude;
    if (spot.longitude > maxLng) maxLng = spot.longitude;
  }

  // Add 5% margin
  final latMargin = (maxLat - minLat) * 0.05;
  final lngMargin = (maxLng - minLng) * 0.05;

  // Handle edge case where all spots are at the same location
  if (latMargin == 0) {
    minLat -= 0.01;
    maxLat += 0.01;
  } else {
    minLat -= latMargin;
    maxLat += latMargin;
  }

  if (lngMargin == 0) {
    minLng -= 0.01;
    maxLng += 0.01;
  } else {
    minLng -= lngMargin;
    maxLng += lngMargin;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

