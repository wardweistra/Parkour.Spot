import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's RSVP on an event: going or interested (not a registration).
enum EventInterestStatus { going, interested }

EventInterestStatus? parseEventInterestStatus(Object? raw) {
  if (raw is! String) return null;
  switch (raw.trim()) {
    case 'going':
      return EventInterestStatus.going;
    case 'interested':
      return EventInterestStatus.interested;
    default:
      return null;
  }
}

extension EventInterestStatusWire on EventInterestStatus {
  String get wireValue => switch (this) {
    EventInterestStatus.going => 'going',
    EventInterestStatus.interested => 'interested',
  };
}

/// One user's interest in an event (`users/{userId}/eventInterests/{eventId}`).
class EventInterest {
  const EventInterest({
    required this.eventId,
    required this.userId,
    required this.status,
    this.eventStartAt,
    this.createdAt,
    this.updatedAt,
  });

  final String eventId;
  final String userId;
  final EventInterestStatus status;
  final DateTime? eventStartAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EventInterest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String userId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return EventInterest.fromMap(data, eventId: doc.id, userId: userId);
  }

  factory EventInterest.fromMap(
    Map<String, dynamic> data, {
    required String eventId,
    required String userId,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final storedEventId = (data['eventId'] as String?)?.trim();
    final storedUserId = (data['userId'] as String?)?.trim();
    final status =
        parseEventInterestStatus(data['status']) ??
        EventInterestStatus.interested;

    return EventInterest(
      eventId: (storedEventId != null && storedEventId.isNotEmpty)
          ? storedEventId
          : eventId,
      userId: (storedUserId != null && storedUserId.isNotEmpty)
          ? storedUserId
          : userId,
      status: status,
      eventStartAt: parseDate(data['eventStartAt']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }
}

/// Public totals for an event (`eventInterestStats/{eventId}`).
class EventInterestStats {
  const EventInterestStats({this.goingCount = 0, this.interestedCount = 0});

  static const EventInterestStats empty = EventInterestStats();

  final int goingCount;
  final int interestedCount;

  factory EventInterestStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return EventInterestStats.empty;
    return EventInterestStats(
      goingCount: _nonNegativeInt(data['goingCount']),
      interestedCount: _nonNegativeInt(data['interestedCount']),
    );
  }

  factory EventInterestStats.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return EventInterestStats.fromMap(doc.data());
  }

  static int _nonNegativeInt(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final asInt = value.toInt();
      return asInt < 0 ? 0 : asInt;
    }
    return 0;
  }
}
