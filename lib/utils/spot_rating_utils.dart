import '../models/rating.dart';
import '../models/spot.dart';

String? _trimmedId(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Listing the user is viewing. Ratings are stored against this id.
String? spotRatingWriteSpotId(Spot spot) => _trimmedId(spot.id);

/// Spot whose average / count include this listing (native when duplicate).
String? canonicalSpotRatingSpotId(Spot spot) {
  return _trimmedId(spot.duplicateOf) ?? _trimmedId(spot.id);
}

/// Native spot plus this listing and any extra duplicate/native ids.
Set<String> spotRatingClusterIds({
  required Spot spot,
  Iterable<String> extraIds = const [],
}) {
  final ids = <String>{};
  void add(String? id) {
    final trimmed = _trimmedId(id);
    if (trimmed != null) ids.add(trimmed);
  }

  add(spot.id);
  add(spot.duplicateOf);
  for (final id in extraIds) {
    add(id);
  }
  return ids;
}

DateTime _ratingRecency(Rating rating) {
  return rating.updatedAt ??
      rating.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Latest updatedAt wins (`createdAt` if `updatedAt` is missing).
Rating? uniqueUserRating(Iterable<Rating> ratings) {
  Rating? best;
  for (final rating in ratings) {
    if (best == null || _ratingRecency(rating).isAfter(_ratingRecency(best))) {
      best = rating;
    }
  }
  return best;
}

/// Listing spot ids whose ratings should be deleted for this user.
///
/// Clearing removes every cluster listing. Setting a rating keeps the listing
/// being viewed and deletes the siblings.
Set<String> spotRatingSpotIdsToDelete({
  required String listingSpotId,
  required Iterable<String> clusterSpotIds,
  required bool clearing,
}) {
  final listingId = listingSpotId.trim();
  final cluster = <String>{
    if (listingId.isNotEmpty) listingId,
    ...clusterSpotIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
  };
  if (clearing) return cluster;
  if (listingId.isEmpty) return cluster;
  return cluster.difference({listingId});
}
