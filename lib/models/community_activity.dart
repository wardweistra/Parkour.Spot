import 'event_map_pin.dart';

/// Kinds of materialized `communityActivity` documents (see
/// `functions/lib/community-activity.js`).
enum CommunityActivityKind {
  spotAdded,
  spotPhotoAdded,
  spotCheckIn,
  spotTrainingPlan,
  eventEnded,
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
    case 'event_ended':
      return CommunityActivityKind.eventEnded;
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
    if (kind == null || kind == CommunityActivityKind.eventEnded) {
      return null;
    }
    final id = data['id'];
    final spotId = data['spotId'];
    final lat = data['latitude'];
    final lng = data['longitude'];
    final occurredAt = _parseDate(data['occurredAt']);
    if (id is! String ||
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

/// An upcoming or past event in the viewport with public Going / Interested
/// totals.
class CommunityEventItem {
  const CommunityEventItem({
    required this.pin,
    this.goingCount = 0,
    this.interestedCount = 0,
    this.isPast = false,
  });

  final EventMapPin pin;
  final int goingCount;
  final int interestedCount;

  /// True when this row came from a past `event_ended` activity document.
  final bool isPast;

  /// Sort key for the past half of the stream (newest first from the API).
  DateTime get occurredAt => pin.endAt ?? pin.startAt;

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

  /// Builds a past event card from a normalized `event_ended` activity map.
  static CommunityEventItem? fromEndedActivityMap(Map<String, dynamic> data) {
    if (parseCommunityActivityKind(data['kind']) !=
        CommunityActivityKind.eventEnded) {
      return null;
    }
    final id = data['id'];
    final eventId = data['eventId'];
    final title = data['title'];
    final lat = data['latitude'];
    final lng = data['longitude'];
    final startAt = CommunityActivityItem._parseDate(data['startAt']);
    if (id is! String ||
        eventId is! String ||
        title is! String ||
        lat is! num ||
        lng is! num ||
        startAt == null) {
      return null;
    }
    final pinKindRaw = data['pinKind'] as String?;
    final kind = pinKindRaw == 'spot'
        ? EventMapPinKind.spot
        : EventMapPinKind.venue;
    return CommunityEventItem(
      pin: EventMapPin(
        id: id,
        eventId: eventId,
        kind: kind,
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        title: title,
        startAt: startAt,
        endAt: CommunityActivityItem._parseDate(data['endAt']),
        isDateOnly: data['isDateOnly'] == true,
        timeZone: data['timeZone'] as String?,
        spotId: data['spotId'] as String?,
        description: data['description'] as String?,
        imageUrls: data['imageUrls'] is List
            ? List<String>.from(
                (data['imageUrls'] as List).whereType<String>(),
              )
            : const [],
        city: data['city'] as String?,
        countryCode: data['countryCode'] as String?,
      ),
      goingCount: _nonNegativeInt(data['goingCount']),
      interestedCount: _nonNegativeInt(data['interestedCount']),
      isPast: true,
    );
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
    this.pastEvents = const [],
    this.upcoming = const [],
    this.events = const [],
  });

  static const CommunityActivityFeed empty = CommunityActivityFeed();

  /// Newest first (closest to "now" is at the bottom of this list).
  final List<CommunityActivityItem> past;

  /// Newest first; ended events mixed into the past half of the stream.
  final List<CommunityEventItem> pastEvents;

  /// Soonest first.
  final List<CommunityActivityItem> upcoming;

  /// Soonest first, deduped by event id.
  final List<CommunityEventItem> events;

  int get itemCount =>
      past.length + pastEvents.length + upcoming.length + events.length;
  bool get isEmpty => itemCount == 0;

  factory CommunityActivityFeed.fromCallableMap(Map<String, dynamic> data) {
    List<Map<String, dynamic>> maps(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final pastMaps = maps(data['past']);
    final past = <CommunityActivityItem>[];
    final pastEvents = <CommunityEventItem>[];
    for (final map in pastMaps) {
      if (map['kind'] == 'event_ended') {
        final event = CommunityEventItem.fromEndedActivityMap(map);
        if (event != null) pastEvents.add(event);
      } else {
        final item = CommunityActivityItem.fromCallableMap(map);
        if (item != null) past.add(item);
      }
    }

    return CommunityActivityFeed(
      past: past,
      pastEvents: pastEvents,
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
