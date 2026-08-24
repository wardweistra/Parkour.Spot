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
      updates['spotFeatures'] = duplicate.spotFeatures;
    }
    if (duplicate.spotFacilities != null &&
        duplicate.spotFacilities!.isNotEmpty) {
      updates['spotFacilities'] = duplicate.spotFacilities;
    }
    if (duplicate.goodFor != null && duplicate.goodFor!.isNotEmpty) {
      updates['goodFor'] = duplicate.goodFor;
    }
  }

  return updates;
}

bool _isNativeSpot(Spot spot) {
  final source = spot.spotSource?.trim();
  return source == null || source.isEmpty;
}

/// Whether [spot] is a native parkour.spot spot (not from an external source).
bool spotIsNative(Spot spot) => _isNativeSpot(spot);
