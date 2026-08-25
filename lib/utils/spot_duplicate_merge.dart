import '../models/spot.dart';

/// Builds Firestore field updates to apply to [original] when merging data from
/// [duplicate]. Returns an empty map when nothing changes.
Map<String, dynamic> buildSpotDuplicateMergeUpdates({
  required Spot original,
  required Spot duplicate,
  bool transferPhotos = false,
  bool transferYoutubeLinks = false,
  bool overwriteName = false,
  bool overwriteDescription = false,
  bool overwriteLocation = false,
  bool overwriteSpotAttributes = false,
}) {
  final updates = <String, dynamic>{};

  if (transferPhotos &&
      duplicate.imageUrls != null &&
      duplicate.imageUrls!.isNotEmpty) {
    final existingPhotos = List<String>.from(original.imageUrls ?? []);
    final newPhotos = duplicate.imageUrls!
        .where((url) => !existingPhotos.contains(url))
        .toList();
    if (newPhotos.isNotEmpty) {
      updates['imageUrls'] = [...existingPhotos, ...newPhotos];
      updates['hasImages'] = true;
    }
  }

  if (transferYoutubeLinks &&
      duplicate.youtubeVideoIds != null &&
      duplicate.youtubeVideoIds!.isNotEmpty) {
    final existingYoutubeLinks = List<String>.from(
      original.youtubeVideoIds ?? [],
    );
    final newYoutubeLinks = duplicate.youtubeVideoIds!
        .where((id) => !existingYoutubeLinks.contains(id))
        .toList();
    if (newYoutubeLinks.isNotEmpty) {
      updates['youtubeVideoIds'] = [
        ...existingYoutubeLinks,
        ...newYoutubeLinks,
      ];
    }
  }

  if (overwriteName && duplicate.name.trim().isNotEmpty) {
    updates['name'] = duplicate.name.trim();
  }

  if (overwriteDescription && duplicate.description.trim().isNotEmpty) {
    updates['description'] = duplicate.description.trim();
  }

  if (overwriteLocation) {
    var hasLocationData = false;
    if (duplicate.latitude != 0.0 && duplicate.longitude != 0.0) {
      updates['latitude'] = duplicate.latitude;
      updates['longitude'] = duplicate.longitude;
      hasLocationData = true;
    }
    if (duplicate.address != null && duplicate.address!.isNotEmpty) {
      updates['address'] = duplicate.address;
      hasLocationData = true;
    }
    if (duplicate.city != null && duplicate.city!.isNotEmpty) {
      updates['city'] = duplicate.city;
      hasLocationData = true;
    }
    if (duplicate.countryCode != null && duplicate.countryCode!.isNotEmpty) {
      updates['countryCode'] = duplicate.countryCode;
      hasLocationData = true;
    }
    if (!hasLocationData) {
      updates.remove('latitude');
      updates.remove('longitude');
    }
  }

  if (overwriteSpotAttributes) {
    if (duplicate.spotAccess != null && duplicate.spotAccess!.isNotEmpty) {
      updates['spotAccess'] = duplicate.spotAccess;
    }
    if (duplicate.spotFeatures != null && duplicate.spotFeatures!.isNotEmpty) {
      final existingFeatures = List<String>.from(original.spotFeatures ?? []);
      final newFeatures = duplicate.spotFeatures!
          .where(
            (value) =>
                value.trim().isNotEmpty && !existingFeatures.contains(value),
          )
          .toList();
      if (newFeatures.isNotEmpty) {
        updates['spotFeatures'] = [...existingFeatures, ...newFeatures];
      }
    }
    if (duplicate.spotFacilities != null &&
        duplicate.spotFacilities!.isNotEmpty) {
      final existingFacilities = Map<String, String>.from(
        original.spotFacilities ?? {},
      );
      final mergedFacilities = mergeSpotFacilityMaps([
        existingFacilities,
        duplicate.spotFacilities,
      ]);
      if (mergedFacilities != null &&
          !_facilityMapsEqual(existingFacilities, mergedFacilities)) {
        updates['spotFacilities'] = mergedFacilities;
      }
    }
    if (duplicate.goodFor != null && duplicate.goodFor!.isNotEmpty) {
      final existingGoodFor = List<String>.from(original.goodFor ?? []);
      final newGoodFor = duplicate.goodFor!
          .where(
            (value) =>
                value.trim().isNotEmpty && !existingGoodFor.contains(value),
          )
          .toList();
      if (newGoodFor.isNotEmpty) {
        updates['goodFor'] = [...existingGoodFor, ...newGoodFor];
      }
    }
  }

  return updates;
}

/// Whether a facility value counts as enabled (`true` / `yes`).
bool isSpotFacilityEnabled(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == 'true' || normalized == 'yes';
}

/// Merges facility maps from [sources] in order.
///
/// Missing keys are added. When the same key appears more than once, an enabled
/// value wins over a disabled one; otherwise the first value is kept.
Map<String, String>? mergeSpotFacilityMaps(
  Iterable<Map<String, String>?> sources,
) {
  final merged = <String, String>{};
  for (final source in sources) {
    if (source == null || source.isEmpty) continue;
    for (final entry in source.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      if (!merged.containsKey(key)) {
        merged[key] = entry.value;
      } else if (isSpotFacilityEnabled(entry.value) &&
          !isSpotFacilityEnabled(merged[key])) {
        merged[key] = entry.value;
      }
    }
  }
  return merged.isEmpty ? null : merged;
}

bool _facilityMapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _isNativeSpot(Spot spot) {
  final source = spot.spotSource?.trim();
  return source == null || source.isEmpty;
}

/// Whether [spot] is a native parkour.spot spot (not from an external source).
bool spotIsNative(Spot spot) => _isNativeSpot(spot);
