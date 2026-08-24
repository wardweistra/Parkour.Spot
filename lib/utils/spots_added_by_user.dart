import '../models/spot.dart';

/// Built-in private lists on the Spot lists hub (not shareable SpotList docs).
enum SpotTrackingListType { wantToVisit, visited, added }

/// Whether [spot] belongs on the signed-in user's private added-spots list.
bool isSpotAddedByUser(Spot spot, String userId) {
  final createdBy = spot.createdBy?.trim() ?? '';
  return userId.isNotEmpty && createdBy == userId;
}

/// Newest first, then name. Used for the private "added by you" list.
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

/// Profile route for a built-in tracking list. These lists are private.
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
