/// Contribution totals for one user, read from `userStats/{uid}`
/// (maintained by `functions/lib/user-stats.js`).
///
/// Private check-ins are never counted and only public lists are, so these
/// numbers are safe to show on a public profile.
class UserContributionStats {
  const UserContributionStats({
    this.spotsAdded = 0,
    this.spotsImproved = 0,
    this.photosAdded = 0,
    this.eventsCreated = 0,
    this.eventsImproved = 0,
    this.ratings = 0,
    this.lists = 0,
    this.checkIns = 0,
  });

  static const empty = UserContributionStats();

  final int spotsAdded;
  final int spotsImproved;
  final int photosAdded;
  final int eventsCreated;
  final int eventsImproved;
  final int ratings;
  final int lists;
  final int checkIns;

  int get total =>
      spotsAdded +
      spotsImproved +
      photosAdded +
      eventsCreated +
      eventsImproved +
      ratings +
      lists +
      checkIns;

  bool get isEmpty => total == 0;

  /// Parses one stats map (`allTime` or a `years.<year>` entry).
  factory UserContributionStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    int read(String key) {
      final value = map[key];
      return value is num && value > 0 ? value.toInt() : 0;
    }

    return UserContributionStats(
      spotsAdded: read('spotsAdded'),
      spotsImproved: read('spotsImproved'),
      photosAdded: read('photosAdded'),
      eventsCreated: read('eventsCreated'),
      eventsImproved: read('eventsImproved'),
      ratings: read('ratings'),
      lists: read('lists'),
      checkIns: read('checkIns'),
    );
  }

  /// All-time totals from a `userStats/{uid}` document; missing → [empty].
  factory UserContributionStats.allTimeFromDocument(
    Map<String, dynamic>? data,
  ) {
    final allTime = data?['allTime'];
    return UserContributionStats.fromMap(
      allTime is Map ? Map<String, dynamic>.from(allTime) : null,
    );
  }

  /// Totals for one UTC calendar [year]; missing → [empty].
  factory UserContributionStats.yearFromDocument(
    Map<String, dynamic>? data,
    int year,
  ) {
    final years = data?['years'];
    final yearStats = years is Map ? years['$year'] : null;
    return UserContributionStats.fromMap(
      yearStats is Map ? Map<String, dynamic>.from(yearStats) : null,
    );
  }
}

/// One read of `userStats/{uid}`: all-time totals and, optionally, one year.
class ContributionStatsSnapshot {
  const ContributionStatsSnapshot({
    required this.allTime,
    this.year,
    this.yearStats = UserContributionStats.empty,
  });

  final UserContributionStats allTime;

  /// The year [yearStats] covers, or null when none was requested.
  final int? year;
  final UserContributionStats yearStats;
}
