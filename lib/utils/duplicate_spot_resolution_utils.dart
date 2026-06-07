import 'dart:math' as math;

import '../models/spot.dart';

class DuplicateSpotPairRef {
  const DuplicateSpotPairRef({
    required this.spot1Id,
    required this.spot2Id,
    required this.distanceMeters,
  });

  final String spot1Id;
  final String spot2Id;
  final int distanceMeters;

  static DuplicateSpotPairRef? fromMap(Map<String, dynamic> pair) {
    final spot1 = pair['spot1'] as Map<String, dynamic>?;
    final spot2 = pair['spot2'] as Map<String, dynamic>?;
    final spot1Id = spot1?['id'] as String?;
    final spot2Id = spot2?['id'] as String?;
    if (spot1Id == null || spot2Id == null) return null;
    return DuplicateSpotPairRef(
      spot1Id: spot1Id,
      spot2Id: spot2Id,
      distanceMeters: (pair['distanceMeters'] as num?)?.round() ?? 0,
    );
  }
}

Set<String> buildConnectedDuplicateSpotIds({
  required List<DuplicateSpotPairRef> pairs,
  required int startIndex,
  int maxDistanceMeters = 50,
}) {
  if (startIndex < 0 || startIndex >= pairs.length) return <String>{};

  final startPair = pairs[startIndex];
  final cluster = <String>{startPair.spot1Id, startPair.spot2Id};
  var changed = true;

  while (changed) {
    changed = false;
    for (final pair in pairs) {
      if (pair.distanceMeters > maxDistanceMeters) continue;
      final touchesCluster =
          cluster.contains(pair.spot1Id) || cluster.contains(pair.spot2Id);
      if (!touchesCluster) continue;
      changed = cluster.add(pair.spot1Id) || changed;
      changed = cluster.add(pair.spot2Id) || changed;
    }
  }

  return cluster;
}

List<int> findPairIndicesWithinCluster({
  required List<DuplicateSpotPairRef> pairs,
  required Set<String> clusterSpotIds,
  int maxDistanceMeters = 50,
}) {
  final indices = <int>[];
  for (var i = 0; i < pairs.length; i++) {
    final pair = pairs[i];
    if (pair.distanceMeters <= maxDistanceMeters &&
        clusterSpotIds.contains(pair.spot1Id) &&
        clusterSpotIds.contains(pair.spot2Id)) {
      indices.add(i);
    }
  }
  return indices;
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

Map<String, double> boundsForRadiusMeters({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) {
  final latOffset = radiusMeters / 111000.0;
  final cosLat = math.cos(latitude * math.pi / 180.0).abs();
  final lngOffset = cosLat < 0.000001 ? 180.0 : latOffset / cosLat;

  return {
    'minLat': latitude - latOffset,
    'maxLat': latitude + latOffset,
    'minLng': longitude - lngOffset,
    'maxLng': longitude + lngOffset,
  };
}

Spot buildDuplicateNativeSpotPreview({
  required List<Spot> spots,
  required String baseSpotId,
  required String titleSpotId,
  required String descriptionSpotId,
  required String locationSpotId,
  required String attributesSpotId,
  required Set<String> photoSpotIds,
  required Set<String> youtubeSpotIds,
}) {
  if (spots.isEmpty) {
    throw ArgumentError.value(spots, 'spots', 'Must include at least one spot');
  }

  final baseSpot = _spotByIdOrFallback(spots, baseSpotId);
  final titleSpot = _spotByIdOrFallback(spots, titleSpotId, baseSpot);
  final descriptionSpot = _spotByIdOrFallback(
    spots,
    descriptionSpotId,
    baseSpot,
  );
  final locationSpot = _spotByIdOrFallback(spots, locationSpotId, baseSpot);
  final attributesSpot = _spotByIdOrFallback(spots, attributesSpotId, baseSpot);

  final imageUrls = _dedupe(
    spots
        .where((spot) => photoSpotIds.contains(spot.id))
        .expand((spot) => spot.imageUrls ?? const <String>[]),
  );
  final youtubeIds = _dedupe(
    spots
        .where((spot) => youtubeSpotIds.contains(spot.id))
        .expand((spot) => spot.youtubeVideoIds ?? const <String>[]),
  );

  return Spot(
    name: titleSpot.name.isNotEmpty ? titleSpot.name : baseSpot.name,
    description: descriptionSpot.description.isNotEmpty
        ? descriptionSpot.description
        : baseSpot.description,
    latitude: locationSpot.latitude,
    longitude: locationSpot.longitude,
    address: locationSpot.address,
    city: locationSpot.city,
    countryCode: locationSpot.countryCode,
    imageUrls: imageUrls.isEmpty ? null : imageUrls,
    youtubeVideoIds: youtubeIds.isEmpty ? null : youtubeIds,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    averageRating: 0,
    ratingCount: 0,
    wilsonLowerBound: 0,
    ranking: baseSpot.ranking,
    spotAccess: attributesSpot.spotAccess,
    spotFeatures: _copyList(attributesSpot.spotFeatures),
    spotFacilities: attributesSpot.spotFacilities == null
        ? null
        : Map<String, String>.from(attributesSpot.spotFacilities!),
    goodFor: _copyList(attributesSpot.goodFor),
    duplicateOf: null,
    hidden: false,
    createdFromCreateNative: true,
  );
}

Spot _spotByIdOrFallback(List<Spot> spots, String id, [Spot? fallback]) {
  for (final spot in spots) {
    if (spot.id == id) return spot;
  }
  return fallback ?? spots.first;
}

List<String>? _copyList(List<String>? values) {
  return values == null ? null : List<String>.from(values);
}

List<String> _dedupe(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    if (value.trim().isEmpty || seen.contains(value)) continue;
    seen.add(value);
    result.add(value);
  }
  return result;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
