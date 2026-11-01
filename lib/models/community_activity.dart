import 'event_map_pin.dart';

/// Kinds of materialized `communityActivity` documents (see
/// `functions/lib/community-activity.js`).
enum CommunityActivityKind {
  spotAdded,
  spotPhotoAdded,
  spotCheckIn,
  spotTrainingPlan,
}

CommunityActivityKind? parseCommunityActivityKind(Object? raw) {
  switch (raw) {
    case 'spot_added':
      return CommunityActivityKind.spotAdded;
    case 'spot_photo_added':
      return CommunityActivityKind.spotPhotoAdded;
    case 'spot_check_in':
      return CommunityActivityKind.spotCheckIn;
    case 'spot_training_plan':
      return CommunityActivityKind.spotTrainingPlan;
    default:
      return null;
  }
}

/// One spot-anchored community activity item returned by
/// `getCommunityActivityInBounds`.
class CommunityActivityItem {
  const CommunityActivityItem({
    required this.id,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
    required this.spotId,
    this.startAt,
    this.endAt,
    this.spotName,
    this.city,
    this.countryCode,
    this.actorUserId,
    this.actorDisplayName,
    this.actorPhotoURL,
    this.photoCount,
    this.imageUrls = const [],
    this.comment,
  });

  final String id;
  final CommunityActivityKind kind;
  final double latitude;
  final double longitude;

  /// When the activity happened (past kinds) or was created (upcoming kinds).
  final DateTime occurredAt;

  /// Training plan window; check-ins carry their expected end in [endAt].
  final DateTime? startAt;
  final DateTime? endAt;

  final String spotId;
  final String? spotName;
  final String? city;
  final String? countryCode;

  final String? actorUserId;
  final String? actorDisplayName;
  final String? actorPhotoURL;

  /// Number of photos added for [CommunityActivityKind.spotPhotoAdded].
  final int? photoCount;

  /// Up to three preview image URLs (new photos, or the new spot's images).
  final List<String> imageUrls;
  final String? comment;

  bool get isUpcoming => kind == CommunityActivityKind.spotTrainingPlan;

  /// Whether a check-in or training plan window contains [now].
  bool isActiveAt(DateTime now) {
    final end = endAt;
    if (end == null) return false;
    final start = startAt ?? occurredAt;
    return !now.isBefore(start) && !now.isAfter(end);
  }

  static CommunityActivityItem? fromCallableMap(Map<String, dynamic> data) {
    final kind = parseCommunityActivityKind(data['kind']);
    final id = data['id'];
    final spotId = data['spotId'];
    final lat = data['latitude'];
    final lng = data['longitude'];
    final occurredAt = _parseDate(data['occurredAt']);
    if (kind == null ||
        id is! String ||
        spotId is! String ||
        lat is! num ||
        lng is! num ||
        occurredAt == null) {
      return null;
    }
    final rawCount = data['photoCount'];
    return CommunityActivityItem(
      id: id,
      kind: kind,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      occurredAt: occurredAt,
      startAt: _parseDate(data['startAt']),
      endAt: _parseDate(data['endAt']),
      spotId: spotId,
      spotName: data['spotName'] as String?,
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
      actorUserId: data['actorUserId'] as String?,
      actorDisplayName: data['actorDisplayName'] as String?,
      actorPhotoURL: data['actorPhotoURL'] as String?,
      photoCount: rawCount is num ? rawCount.toInt() : null,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from((data['imageUrls'] as List).whereType<String>())
          : const [],
      comment: data['comment'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is DateTime) return value.toUtc();
    return null;
  }
}

/// An upcoming event in the viewport with public Going / Interested totals.
class CommunityEventItem {
  const CommunityEventItem({
    required this.pin,
    this.goingCount = 0,
    this.interestedCount = 0,
  });

  final EventMapPin pin;
  final int goingCount;
  final int interestedCount;

  static CommunityEventItem? fromCallableMap(Map<String, dynamic> data) {
    try {
      final pin = EventMapPin.fromCallableMap(data);
      return CommunityEventItem(
        pin: pin,
        goingCount: _nonNegativeInt(data['goingCount']),
        interestedCount: _nonNegativeInt(data['interestedCount']),
      );
    } catch (_) {
      return null;
    }
  }

  static int _nonNegativeInt(Object? value) {
    if (value is num) {
      final asInt = value.toInt();
      return asInt < 0 ? 0 : asInt;
    }
    return 0;
  }
}

/// Everything the Explore Community stream shows for one viewport.
class CommunityActivityFeed {
  const CommunityActivityFeed({
    this.past = const [],
    this.upcoming = const [],
    this.events = const [],
  });

  static const CommunityActivityFeed empty = CommunityActivityFeed();

  /// Newest first (closest to "now" is at the bottom of this list).
  final List<CommunityActivityItem> past;

  /// Soonest first.
  final List<CommunityActivityItem> upcoming;

  /// Soonest first, deduped by event id.
  final List<CommunityEventItem> events;

  int get itemCount => past.length + upcoming.length + events.length;
  bool get isEmpty => itemCount == 0;

  factory CommunityActivityFeed.fromCallableMap(Map<String, dynamic> data) {
    List<Map<String, dynamic>> maps(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return CommunityActivityFeed(
      past: maps(data['past'])
          .map(CommunityActivityItem.fromCallableMap)
          .whereType<CommunityActivityItem>()
          .toList(),
      upcoming: maps(data['upcoming'])
          .map(CommunityActivityItem.fromCallableMap)
          .whereType<CommunityActivityItem>()
          .toList(),
      events: maps(data['events'])
          .map(CommunityEventItem.fromCallableMap)
          .whereType<CommunityEventItem>()
          .toList(),
    );
  }
}
