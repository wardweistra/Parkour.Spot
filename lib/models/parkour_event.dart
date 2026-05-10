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
  });

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
    );
  }

  static const Object _unset = Object();
}
