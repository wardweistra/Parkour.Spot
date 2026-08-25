import 'dart:math' as math;

import '../models/spot.dart';
import 'spot_duplicate_merge.dart';

bool isSpotAlreadyMarkedAsDuplicate(Spot spot) {
  final duplicateOf = spot.duplicateOf?.trim();
  return duplicateOf != null && duplicateOf.isNotEmpty;
}

/// Safely reads a Firestore map on web where values may be JS interop objects.
Map<String, dynamic> firestoreMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

Map<String, dynamic>? firestoreMapOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int firestoreInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

Set<int> firestoreIntSet(Iterable<dynamic>? values) {
  if (values == null) return {};
  return values.map(firestoreInt).toSet();
}

bool isPairResolvedToNative(Map<String, dynamic> pairResolutions, int index) {
  final resolution = firestoreMapOrNull(pairResolutions[index.toString()]);
  return resolution?['status'] == 'resolved_to_native';
}

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
    final spot1 = firestoreMapOrNull(pair['spot1']);
    final spot2 = firestoreMapOrNull(pair['spot2']);
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

int duplicateClusterOptionalDetailScore(Spot spot) {
  var score = 0;
  if (spot.description.trim().isNotEmpty) score++;
  score += spot.imageUrls?.length ?? 0;
  score += spot.youtubeVideoIds?.length ?? 0;
  if (spot.spotAccess != null && spot.spotAccess!.trim().isNotEmpty) score++;
  score += spot.spotFeatures?.length ?? 0;
  score += spot.goodFor?.length ?? 0;
  score += _enabledFacilityCount(spot);
  if (_hasOptionalLocationDetail(spot)) score++;
  return score;
}

int _enabledFacilityCount(Spot spot) {
  var count = 0;
  spot.spotFacilities?.forEach((_, value) {
    if (isSpotFacilityEnabled(value)) count++;
  });
  return count;
}

List<String> _enabledFacilityKeys(Spot spot) {
  final keys = <String>[];
  spot.spotFacilities?.forEach((key, value) {
    if (isSpotFacilityEnabled(value) && key.trim().isNotEmpty) {
      keys.add(key);
    }
  });
  return keys;
}

bool _hasOptionalLocationDetail(Spot spot) {
  return [
    spot.address,
    spot.city,
    spot.countryCode,
  ].any((value) => value?.trim().isNotEmpty ?? false);
}

int compareSpotsByOptionalDetailRichness(Spot a, Spot b) {
  final scoreDiff =
      duplicateClusterOptionalDetailScore(b) -
      duplicateClusterOptionalDetailScore(a);
  if (scoreDiff != 0) return scoreDiff;

  final aIsNative = a.spotSource == null;
  final bIsNative = b.spotSource == null;
  if (aIsNative != bIsNative) {
    return aIsNative ? -1 : 1;
  }

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

List<Spot> sortSpotsByOptionalDetailRichness(List<Spot> spots) {
  final ordered = List<Spot>.from(spots);
  ordered.sort(compareSpotsByOptionalDetailRichness);
  return ordered;
}

bool isParkourSpotNativeSpot(Spot spot) => spot.spotSource == null;

String pickDuplicateClusterBasisSpotId(List<Spot> spots) {
  final withIds = spots
      .where((spot) => spot.id != null)
      .toList(growable: false);
  if (withIds.isEmpty) {
    throw ArgumentError.value(
      spots,
      'spots',
      'Must include at least one spot with an id',
    );
  }

  final natives = withIds
      .where(isParkourSpotNativeSpot)
      .toList(growable: false);
  final candidates = natives.isNotEmpty ? natives : withIds;
  return sortSpotsByOptionalDetailRichness(candidates).first.id!;
}

class DuplicateClusterMergeDefaults {
  const DuplicateClusterMergeDefaults({
    required this.basisSpotId,
    required this.titleSpotId,
    required this.descriptionSpotId,
    required this.locationSpotId,
    required this.accessSpotId,
    required this.facilitiesSpotIds,
    required this.featureSpotIds,
    required this.goodForSpotIds,
    required this.photoSpotIds,
    required this.youtubeSpotIds,
  });

  final String basisSpotId;
  final String titleSpotId;
  final String descriptionSpotId;
  final String locationSpotId;
  final String accessSpotId;
  final Set<String> facilitiesSpotIds;
  final Set<String> featureSpotIds;
  final Set<String> goodForSpotIds;
  final Set<String> photoSpotIds;
  final Set<String> youtubeSpotIds;
}

DuplicateClusterMergeDefaults buildDuplicateClusterMergeDefaults(
  List<Spot> spots,
) {
  if (spots.isEmpty) {
    throw ArgumentError.value(spots, 'spots', 'Must include at least one spot');
  }

  final basisSpotId = pickDuplicateClusterBasisSpotId(spots);

  return DuplicateClusterMergeDefaults(
    basisSpotId: basisSpotId,
    titleSpotId:
        _soleDetailProviderSpotId(
          spots,
          basisSpotId,
          (spot) => spot.name.trim().isNotEmpty,
        ) ??
        basisSpotId,
    descriptionSpotId:
        _soleDetailProviderSpotId(
          spots,
          basisSpotId,
          (spot) => spot.description.trim().isNotEmpty,
        ) ??
        basisSpotId,
    locationSpotId:
        _soleDetailProviderSpotId(
          spots,
          basisSpotId,
          _hasOptionalLocationDetail,
        ) ??
        basisSpotId,
    accessSpotId:
        _soleDetailProviderSpotId(
          spots,
          basisSpotId,
          (spot) =>
              spot.spotAccess != null && spot.spotAccess!.trim().isNotEmpty,
        ) ??
        basisSpotId,
    facilitiesSpotIds: _defaultTraitSpotIds(
      spots,
      basisSpotId,
      _enabledFacilityKeys,
    ),
    featureSpotIds: _defaultTraitSpotIds(
      spots,
      basisSpotId,
      (spot) => spot.spotFeatures,
    ),
    goodForSpotIds: _defaultTraitSpotIds(
      spots,
      basisSpotId,
      (spot) => spot.goodFor,
    ),
    photoSpotIds: _defaultMediaSpotIds(
      spots,
      (spot) => spot.imageUrls?.isNotEmpty ?? false,
    ),
    youtubeSpotIds: _defaultMediaSpotIds(
      spots,
      (spot) => spot.youtubeVideoIds?.isNotEmpty ?? false,
    ),
  );
}

String? _soleDetailProviderSpotId(
  List<Spot> spots,
  String basisSpotId,
  bool Function(Spot spot) hasDetail,
) {
  final providers = spots
      .where((spot) => spot.id != null && hasDetail(spot))
      .toList(growable: false);
  if (providers.length == 1) {
    return providers.first.id;
  }
  return null;
}

Set<String> _defaultTraitSpotIds(
  List<Spot> spots,
  String basisSpotId,
  List<String>? Function(Spot spot) readTags,
) {
  final selected = <String>{};
  final tagOwners = <String, List<String>>{};

  for (final spot in spots) {
    final spotId = spot.id;
    if (spotId == null) continue;
    for (final tag in readTags(spot) ?? const <String>[]) {
      if (tag.trim().isEmpty) continue;
      tagOwners.putIfAbsent(tag, () => []).add(spotId);
    }
  }

  for (final owners in tagOwners.values) {
    if (owners.length == 1) {
      selected.add(owners.single);
    }
  }

  final basis = spots.where((spot) => spot.id == basisSpotId).firstOrNull;
  if (basis != null && (readTags(basis)?.isNotEmpty ?? false)) {
    selected.add(basisSpotId);
  }

  if (selected.isEmpty) {
    final providers = spots
        .where(
          (spot) => spot.id != null && (readTags(spot)?.isNotEmpty ?? false),
        )
        .toList(growable: false);
    if (providers.length == 1) {
      selected.add(providers.first.id!);
    }
  }

  return selected;
}

Set<String> _defaultMediaSpotIds(
  List<Spot> spots,
  bool Function(Spot spot) hasMedia,
) {
  return spots
      .where((spot) => spot.id != null && hasMedia(spot))
      .map((spot) => spot.id!)
      .toSet();
}

Spot buildDuplicateNativeSpotPreview({
  required List<Spot> spots,
  required String baseSpotId,
  required String titleSpotId,
  required String descriptionSpotId,
  required String locationSpotId,
  required String accessSpotId,
  required Set<String> facilitiesSpotIds,
  required Set<String> featureSpotIds,
  required Set<String> goodForSpotIds,
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
  final accessSpot = _spotByIdOrFallback(spots, accessSpotId, baseSpot);

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
  final spotFeatures = _mergeTraitValues(
    spots,
    featureSpotIds,
    (spot) => spot.spotFeatures,
  );
  final goodFor = _mergeTraitValues(
    spots,
    goodForSpotIds,
    (spot) => spot.goodFor,
  );
  final spotFacilities = mergeSpotFacilityMaps(
    spots
        .where((spot) => facilitiesSpotIds.contains(spot.id))
        .map((spot) => spot.spotFacilities),
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
    spotAccess: accessSpot.spotAccess,
    spotFeatures: spotFeatures,
    spotFacilities: spotFacilities,
    goodFor: goodFor,
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

List<String>? _mergeTraitValues(
  List<Spot> spots,
  Set<String> traitSpotIds,
  List<String>? Function(Spot spot) readValues,
) {
  final merged = <String>[];
  final seen = <String>{};
  for (final spot in spots) {
    if (!traitSpotIds.contains(spot.id)) continue;
    for (final value in readValues(spot) ?? const <String>[]) {
      if (value.trim().isEmpty || seen.contains(value)) continue;
      seen.add(value);
      merged.add(value);
    }
  }
  return merged.isEmpty ? null : merged;
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
