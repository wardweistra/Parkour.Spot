import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/spot.dart';

LatLngBounds? _calculateBoundsFromCoordinates({
  required double firstLat,
  required double firstLng,
  required Iterable<({double lat, double lng})> rest,
}) {
  double minLat = firstLat;
  double maxLat = firstLat;
  double minLng = firstLng;
  double maxLng = firstLng;

  for (final point in rest) {
    if (point.lat < minLat) minLat = point.lat;
    if (point.lat > maxLat) maxLat = point.lat;
    if (point.lng < minLng) minLng = point.lng;
    if (point.lng > maxLng) maxLng = point.lng;
  }

  final latMargin = (maxLat - minLat) * 0.05;
  final lngMargin = (maxLng - minLng) * 0.05;

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

/// Calculate bounds to fit all [positions] with 5% margin.
/// Returns null if [positions] is empty.
LatLngBounds? calculateBoundsForLatLngs(Iterable<LatLng> positions) {
  final iterator = positions.iterator;
  if (!iterator.moveNext()) return null;
  final first = iterator.current;
  final rest = <({double lat, double lng})>[];
  while (iterator.moveNext()) {
    final position = iterator.current;
    rest.add((lat: position.latitude, lng: position.longitude));
  }
  return _calculateBoundsFromCoordinates(
    firstLat: first.latitude,
    firstLng: first.longitude,
    rest: rest,
  );
}

/// Calculate bounds to fit all spots with 5% margin
/// Returns null if the spots list is empty
LatLngBounds? calculateBoundsForSpots(List<Spot> spots) {
  if (spots.isEmpty) return null;
  return calculateBoundsForLatLngs(
    spots.map((spot) => LatLng(spot.latitude, spot.longitude)),
  );
}

