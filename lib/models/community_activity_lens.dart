import 'community_activity.dart';

/// Single-select Explore activities lens (All / Events / Sessions / Contributions).
enum CommunityActivityLens {
  all,
  events,
  sessions,
  contributions,
}

extension CommunityActivityLensQuery on CommunityActivityLens {
  /// Firestore `kind` values for `getCommunityActivityInBounds`, or null for All.
  List<String>? get firestoreKinds {
    switch (this) {
      case CommunityActivityLens.all:
        return null;
      case CommunityActivityLens.events:
        return const ['event_ended'];
      case CommunityActivityLens.sessions:
        return const ['spot_check_in', 'spot_training_plan'];
      case CommunityActivityLens.contributions:
        return const ['spot_added', 'spot_photo_added', 'spot_rated'];
    }
  }

  /// Whether upcoming `eventMapPins` should be merged into the feed.
  bool get includeUpcomingEvents {
    switch (this) {
      case CommunityActivityLens.all:
      case CommunityActivityLens.events:
        return true;
      case CommunityActivityLens.sessions:
      case CommunityActivityLens.contributions:
        return false;
    }
  }
}

/// Returns whether [kind] belongs in [lens]. Events are not activity kinds;
/// use [filterCommunityActivityFeed] for event rows / offline tests.
bool communityActivityKindMatchesLens(
  CommunityActivityKind kind,
  CommunityActivityLens lens,
) {
  switch (lens) {
    case CommunityActivityLens.all:
      return true;
    case CommunityActivityLens.events:
      return false;
    case CommunityActivityLens.sessions:
      return kind == CommunityActivityKind.spotCheckIn ||
          kind == CommunityActivityKind.spotTrainingPlan;
    case CommunityActivityLens.contributions:
      return kind == CommunityActivityKind.spotAdded ||
          kind == CommunityActivityKind.spotPhotoAdded ||
          kind == CommunityActivityKind.spotRated;
  }
}

/// Client-side filter kept for unit tests and as a safety net. Production
/// Explore loads use server `kinds` so paging fills each lens correctly.
CommunityActivityFeed filterCommunityActivityFeed(
  CommunityActivityFeed feed,
  CommunityActivityLens lens,
) {
  if (lens == CommunityActivityLens.all) return feed;

  switch (lens) {
    case CommunityActivityLens.all:
      return feed;
    case CommunityActivityLens.events:
      return feed.copyWith(
        past: const [],
        upcoming: const [],
        pastEvents: feed.pastEvents,
        events: feed.events,
      );
    case CommunityActivityLens.sessions:
      return feed.copyWith(
        past: feed.past
            .where(
              (item) => communityActivityKindMatchesLens(item.kind, lens),
            )
            .toList(),
        upcoming: feed.upcoming
            .where(
              (item) => communityActivityKindMatchesLens(item.kind, lens),
            )
            .toList(),
        pastEvents: const [],
        events: const [],
      );
    case CommunityActivityLens.contributions:
      return feed.copyWith(
        past: feed.past
            .where(
              (item) => communityActivityKindMatchesLens(item.kind, lens),
            )
            .toList(),
        upcoming: const [],
        pastEvents: const [],
        events: const [],
      );
  }
}
