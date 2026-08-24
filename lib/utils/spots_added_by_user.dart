import '../models/spot.dart';
import '../models/spot_list.dart';

/// Built-in lists on the Spot lists hub. Added-by-you can be made public.
enum SpotTrackingListType { wantToVisit, visited, added }

/// Whether [spot] belongs on the signed-in user's added-spots list.
bool isSpotAddedByUser(Spot spot, String userId) {
  final createdBy = spot.createdBy?.trim() ?? '';
  return userId.isNotEmpty && createdBy == userId;
}

/// Newest first, then name. Used for the "added by you" list.
List<Spot> sortSpotsAddedByUser(Iterable<Spot> spots) {
  final sorted = List<Spot>.from(spots);
  sorted.sort((a, b) {
    final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byDate = bAt.compareTo(aAt);
    if (byDate != 0) return byDate;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// Owner route for a built-in tracking list.
String spotTrackingListRoutePath(SpotTrackingListType type) {
  switch (type) {
    case SpotTrackingListType.wantToVisit:
      return '/profile/want-to-visit';
    case SpotTrackingListType.visited:
      return '/profile/visited';
    case SpotTrackingListType.added:
      return '/profile/added';
  }
}

/// Public URL for another user's added-spots list.
String addedByUserPublicListPath(String userIdOrUsername) {
  return '/user/$userIdOrUsername/added';
}

String addedByUserListId(String userId) => 'added-by:$userId';

bool isAddedByUserListId(String? id) {
  return id != null && id.startsWith('added-by:');
}

/// Synthetic public list used on profiles when the owner opts in.
SpotList buildAddedByUserSpotList({
  required String userId,
  required String name,
  required int spotCount,
}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return SpotList(
    id: addedByUserListId(userId),
    name: name,
    spotIds: List<String>.generate(spotCount, (index) => '$index'),
    visibility: SpotListVisibility.public,
    createdBy: userId,
    createdAt: epoch,
    updatedAt: epoch,
  );
}
