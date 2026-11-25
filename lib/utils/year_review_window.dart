/// When the yearly review is promoted, and where its pages live.
///
/// The review of year Y opens on 1 December of Y (numbers still update, the
/// card says "Y so far") and is promoted until 31 January of Y + 1. The page
/// itself stays reachable afterwards.
library;

/// Year whose review is promoted at [now] (UTC), or null outside the window.
int? promotedReviewYear(DateTime now) {
  final utc = now.toUtc();
  if (utc.month == DateTime.december) return utc.year;
  if (utc.month == DateTime.january) return utc.year - 1;
  return null;
}

/// In-app path of a review page: `/year/2026/@noor`, or the uid without a
/// username.
String yearReviewPagePath({
  required int year,
  required String userId,
  String? username,
}) {
  final handle = username != null && username.trim().isNotEmpty
      ? '@${username.trim()}'
      : userId;
  return '/year/$year/${Uri.encodeComponent(handle)}';
}
