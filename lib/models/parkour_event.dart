import 'package:cloud_firestore/cloud_firestore.dart';

class ParkourEvent {
  final String? id;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final String? websiteUrl;
  final DateTime startAt;
  final DateTime? endAt;
  final bool isDateOnly;
  final String? timeZone;
  /// `feed` when from ICS; `sourceDefault` when from sync source default.
  final String? timeZoneSource;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? countryCode;
  final List<String> spotIds;
  final List<String> spotListIds;
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
  final List<Map<String, String>> contributors;

  /// When set, this event is a duplicate of the canonical native event [duplicateOf].
  final String? duplicateOf;

  /// Whether this event was created via "Create native event" from an external import.
  final bool createdFromCreateNative;

  /// Whether the event is hidden from public view (map, search, etc.).
  final bool hidden;

  ParkourEvent({
    this.id,
    required this.title,
    this.description,
    this.imageUrls = const <String>[],
    this.websiteUrl,
    required this.startAt,
    this.endAt,
    this.isDateOnly = false,
    this.timeZone,
    this.timeZoneSource,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.countryCode,
    this.spotIds = const <String>[],
    this.spotListIds = const <String>[],
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
    this.contributors = const <Map<String, String>>[],
    this.duplicateOf,
    this.createdFromCreateNative = false,
    this.hidden = false,
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
      isDateOnly: data['isDateOnly'] == true,
      timeZone: data['timeZone'] as String?,
      timeZoneSource: data['timeZoneSource'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : const <String>[],
      spotListIds: data['spotListIds'] is List
          ? List<String>.from(data['spotListIds'])
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
      contributors: data['contributors'] is List
          ? (data['contributors'] as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
          : const <Map<String, String>>[],
      duplicateOf: data['duplicateOf'] as String?,
      createdFromCreateNative: data['createdFromCreateNative'] == true,
      hidden: data['hidden'] == true,
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
      isDateOnly: data['isDateOnly'] == true,
      timeZone: data['timeZone'] as String?,
      timeZoneSource: data['timeZoneSource'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : const <String>[],
      spotListIds: data['spotListIds'] is List
          ? List<String>.from(data['spotListIds'])
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
      contributors: data['contributors'] is List
          ? (data['contributors'] as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
          : const <Map<String, String>>[],
      duplicateOf: data['duplicateOf'] as String?,
      createdFromCreateNative: data['createdFromCreateNative'] == true,
      hidden: data['hidden'] == true,
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
      if (isDateOnly) 'isDateOnly': true,
      if (timeZone != null && timeZone!.trim().isNotEmpty)
        'timeZone': timeZone!.trim(),
      if (timeZoneSource != null && timeZoneSource!.trim().isNotEmpty)
        'timeZoneSource': timeZoneSource!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (countryCode != null && countryCode!.trim().isNotEmpty)
        'countryCode': countryCode!.trim(),
      'spotIds': spotIds,
      'spotListIds': spotListIds,
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
      if (contributors.isNotEmpty) 'contributors': contributors,
      if (duplicateOf != null && duplicateOf!.trim().isNotEmpty)
        'duplicateOf': duplicateOf!.trim(),
      if (createdFromCreateNative) 'createdFromCreateNative': true,
      if (hidden) 'hidden': true,
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
    bool? isDateOnly,
    Object? timeZone = _unset,
    Object? timeZoneSource = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? address = _unset,
    Object? city = _unset,
    Object? countryCode = _unset,
    List<String>? spotIds,
    List<String>? spotListIds,
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
    List<Map<String, String>>? contributors,
    Object? duplicateOf = _unset,
    bool? createdFromCreateNative,
    bool? hidden,
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
      isDateOnly: isDateOnly ?? this.isDateOnly,
      timeZone: identical(timeZone, _unset)
          ? this.timeZone
          : timeZone as String?,
      timeZoneSource: identical(timeZoneSource, _unset)
          ? this.timeZoneSource
          : timeZoneSource as String?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      address: identical(address, _unset) ? this.address : address as String?,
      city: identical(city, _unset) ? this.city : city as String?,
      countryCode: identical(countryCode, _unset)
          ? this.countryCode
          : countryCode as String?,
      spotIds: spotIds ?? this.spotIds,
      spotListIds: spotListIds ?? this.spotListIds,
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
      contributors: contributors ?? this.contributors,
      duplicateOf: identical(duplicateOf, _unset)
          ? this.duplicateOf
          : duplicateOf as String?,
      createdFromCreateNative:
          createdFromCreateNative ?? this.createdFromCreateNative,
      hidden: hidden ?? this.hidden,
    );
  }

  static const Object _unset = Object();
}
