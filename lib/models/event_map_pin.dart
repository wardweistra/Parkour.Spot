import 'package:cloud_firestore/cloud_firestore.dart';

enum EventMapPinKind { venue, spot }

/// Materialized map pin for an upcoming/in-progress event.
class EventMapPin {
  final String id;
  final String eventId;
  final EventMapPinKind kind;
  final double latitude;
  final double longitude;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final String? spotId;
  final String? description;
  final List<String> imageUrls;
  final String? city;
  final String? countryCode;

  const EventMapPin({
    required this.id,
    required this.eventId,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.startAt,
    this.endAt,
    this.spotId,
    this.description,
    this.imageUrls = const [],
    this.city,
    this.countryCode,
  });

  factory EventMapPin.fromCallableMap(Map<String, dynamic> data) {
    final kindRaw = data['kind'] as String?;
    final kind = kindRaw == 'spot'
        ? EventMapPinKind.spot
        : EventMapPinKind.venue;

    return EventMapPin(
      id: data['id'] as String,
      eventId: data['eventId'] as String,
      kind: kind,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      title: (data['title'] as String?) ?? 'Event',
      startAt: DateTime.parse(data['startAt'] as String),
      endAt: data['endAt'] is String
          ? DateTime.parse(data['endAt'] as String)
          : null,
      spotId: data['spotId'] as String?,
      description: data['description'] as String?,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : const [],
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
    );
  }

  factory EventMapPin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final kindRaw = data['kind'] as String?;
    final kind = kindRaw == 'spot'
        ? EventMapPinKind.spot
        : EventMapPinKind.venue;

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      throw FormatException('Invalid date: $value');
    }

    return EventMapPin(
      id: doc.id,
      eventId: data['eventId'] as String,
      kind: kind,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      title: (data['title'] as String?) ?? 'Event',
      startAt: parseDate(data['startAt']),
      endAt: data['endAt'] != null ? parseDate(data['endAt']) : null,
      spotId: data['spotId'] as String?,
      description: data['description'] as String?,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : const [],
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
    );
  }
}
