import 'package:cloud_firestore/cloud_firestore.dart';

class ParkourEvent {
  final String? id;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final String? websiteUrl;
  final DateTime startAt;
  final DateTime? endAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> spotIds;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? eventSourceId;
  final String? eventSourceName;
  final String? externalEventUid;
  final String? externalEventRecurrenceId;
  final String? externalEventKey;
  final DateTime? externalSyncLastSeenAt;
  final DateTime? externalSyncLastChangedAt;
  /// When set, this event is a duplicate of the canonical native event [duplicateOf].
  final String? duplicateOf;

  ParkourEvent({
    this.id,
    required this.title,
    this.description,
    this.imageUrls = const <String>[],
    this.websiteUrl,
    required this.startAt,
    this.endAt,
    this.latitude,
    this.longitude,
    this.address,
    required this.spotIds,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.eventSourceId,
    this.eventSourceName,
    this.externalEventUid,
    this.externalEventRecurrenceId,
    this.externalEventKey,
    this.externalSyncLastSeenAt,
    this.externalSyncLastChangedAt,
    this.duplicateOf,
  });

  /// Native events are authored on parkour.spot (not imported from an external calendar source).
  bool get isNativeEvent =>
      eventSourceId == null || eventSourceId!.trim().isEmpty;

  factory ParkourEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParkourEvent(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: data['description'] as String?,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : const <String>[],
      websiteUrl: data['websiteUrl'] as String?,
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: data['endAt'] is Timestamp
          ? (data['endAt'] as Timestamp).toDate()
          : null,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : const <String>[],
      createdBy: data['createdBy'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      eventSourceId: data['eventSourceId'] as String?,
      eventSourceName: data['eventSourceName'] as String?,
      externalEventUid: data['externalEventUid'] as String?,
      externalEventRecurrenceId: data['externalEventRecurrenceId'] as String?,
      externalEventKey: data['externalEventKey'] as String?,
      externalSyncLastSeenAt: data['externalSyncLastSeenAt'] is Timestamp
          ? (data['externalSyncLastSeenAt'] as Timestamp).toDate()
          : null,
      externalSyncLastChangedAt: data['externalSyncLastChangedAt'] is Timestamp
          ? (data['externalSyncLastChangedAt'] as Timestamp).toDate()
          : null,
      duplicateOf: data['duplicateOf'] as String?,
    );
  }

  factory ParkourEvent.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ParkourEvent(
      id: data['id'] as String?,
      title: (data['title'] ?? '') as String,
      description: data['description'] as String?,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : const <String>[],
      websiteUrl: data['websiteUrl'] as String?,
      startAt: parseDate(data['startAt']) ?? DateTime.now().toUtc(),
      endAt: parseDate(data['endAt']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : const <String>[],
      createdBy: data['createdBy'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      eventSourceId: data['eventSourceId'] as String?,
      eventSourceName: data['eventSourceName'] as String?,
      externalEventUid: data['externalEventUid'] as String?,
      externalEventRecurrenceId: data['externalEventRecurrenceId'] as String?,
      externalEventKey: data['externalEventKey'] as String?,
      externalSyncLastSeenAt: parseDate(data['externalSyncLastSeenAt']),
      externalSyncLastChangedAt: parseDate(data['externalSyncLastChangedAt']),
      duplicateOf: data['duplicateOf'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (websiteUrl != null && websiteUrl!.trim().isNotEmpty)
        'websiteUrl': websiteUrl!.trim(),
      'startAt': startAt.toUtc(),
      if (endAt != null) 'endAt': endAt!.toUtc(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      'spotIds': spotIds,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': createdAt!.toUtc(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc(),
      if (eventSourceId != null && eventSourceId!.trim().isNotEmpty)
        'eventSourceId': eventSourceId!.trim(),
      if (eventSourceName != null && eventSourceName!.trim().isNotEmpty)
        'eventSourceName': eventSourceName!.trim(),
      if (externalEventUid != null && externalEventUid!.trim().isNotEmpty)
        'externalEventUid': externalEventUid!.trim(),
      if (externalEventRecurrenceId != null &&
          externalEventRecurrenceId!.trim().isNotEmpty)
        'externalEventRecurrenceId': externalEventRecurrenceId!.trim(),
      if (externalEventKey != null && externalEventKey!.trim().isNotEmpty)
        'externalEventKey': externalEventKey!.trim(),
      if (externalSyncLastSeenAt != null)
        'externalSyncLastSeenAt': externalSyncLastSeenAt!.toUtc(),
      if (externalSyncLastChangedAt != null)
        'externalSyncLastChangedAt': externalSyncLastChangedAt!.toUtc(),
      if (duplicateOf != null && duplicateOf!.trim().isNotEmpty)
        'duplicateOf': duplicateOf!.trim(),
    };
  }

  ParkourEvent copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? imageUrls,
    Object? websiteUrl = _unset,
    DateTime? startAt,
    Object? endAt = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? address = _unset,
    List<String>? spotIds,
    Object? createdBy = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? eventSourceId = _unset,
    Object? eventSourceName = _unset,
    Object? externalEventUid = _unset,
    Object? externalEventRecurrenceId = _unset,
    Object? externalEventKey = _unset,
    Object? externalSyncLastSeenAt = _unset,
    Object? externalSyncLastChangedAt = _unset,
    Object? duplicateOf = _unset,
  }) {
    return ParkourEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      websiteUrl: identical(websiteUrl, _unset)
          ? this.websiteUrl
          : websiteUrl as String?,
      startAt: startAt ?? this.startAt,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as DateTime?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      address: identical(address, _unset) ? this.address : address as String?,
      spotIds: spotIds ?? this.spotIds,
      createdBy: identical(createdBy, _unset)
          ? this.createdBy
          : createdBy as String?,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
      eventSourceId: identical(eventSourceId, _unset)
          ? this.eventSourceId
          : eventSourceId as String?,
      eventSourceName: identical(eventSourceName, _unset)
          ? this.eventSourceName
          : eventSourceName as String?,
      externalEventUid: identical(externalEventUid, _unset)
          ? this.externalEventUid
          : externalEventUid as String?,
      externalEventRecurrenceId: identical(externalEventRecurrenceId, _unset)
          ? this.externalEventRecurrenceId
          : externalEventRecurrenceId as String?,
      externalEventKey: identical(externalEventKey, _unset)
          ? this.externalEventKey
          : externalEventKey as String?,
      externalSyncLastSeenAt: identical(externalSyncLastSeenAt, _unset)
          ? this.externalSyncLastSeenAt
          : externalSyncLastSeenAt as DateTime?,
      externalSyncLastChangedAt: identical(externalSyncLastChangedAt, _unset)
          ? this.externalSyncLastChangedAt
          : externalSyncLastChangedAt as DateTime?,
      duplicateOf: identical(duplicateOf, _unset)
          ? this.duplicateOf
          : duplicateOf as String?,
    );
  }

  static const Object _unset = Object();
}
