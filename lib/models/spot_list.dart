import 'package:cloud_firestore/cloud_firestore.dart';

enum SpotListVisibility {
  public,
  unlisted,
  private;

  static SpotListVisibility fromString(String? value) {
    switch (value) {
      case 'public':
        return SpotListVisibility.public;
      case 'private':
        return SpotListVisibility.private;
      case 'unlisted':
      default:
        // Legacy lists without this field default to unlisted.
        return SpotListVisibility.unlisted;
    }
  }

  String get firestoreValue {
    switch (this) {
      case SpotListVisibility.public:
        return 'public';
      case SpotListVisibility.unlisted:
        return 'unlisted';
      case SpotListVisibility.private:
        return 'private';
    }
  }

  String get label {
    switch (this) {
      case SpotListVisibility.public:
        return 'Public';
      case SpotListVisibility.unlisted:
        return 'Unlisted';
      case SpotListVisibility.private:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case SpotListVisibility.public:
        return 'Listed on your profile and visible to everyone';
      case SpotListVisibility.unlisted:
        return 'Visible with a direct link, but hidden from your profile';
      case SpotListVisibility.private:
        return 'Only visible to you';
    }
  }
}

class SpotList {
  final String? id;
  final String name;
  final String? description;
  final List<String> spotIds;
  final SpotListVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SpotList({
    this.id,
    required this.name,
    this.description,
    required this.spotIds,
    this.visibility = SpotListVisibility.unlisted,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpotList.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SpotList(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      spotIds: data['spotIds'] != null
          ? List<String>.from(data['spotIds'])
          : [],
      visibility: SpotListVisibility.fromString(data['visibility'] as String?),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  factory SpotList.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        try {
          return DateTime.tryParse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return SpotList(
      id: data['id'] as String?,
      name: (data['name'] ?? '') as String,
      description: data['description'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : [],
      visibility: SpotListVisibility.fromString(data['visibility'] as String?),
      createdBy: (data['createdBy'] ?? '') as String,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'spotIds': spotIds,
      'visibility': visibility.firestoreValue,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  SpotList copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? spotIds,
    SpotListVisibility? visibility,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpotList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      spotIds: spotIds ?? this.spotIds,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get spotCount => spotIds.length;

  @override
  String toString() {
    return 'SpotList(id: $id, name: $name, visibility: ${visibility.label}, spotCount: $spotCount)';
  }
}

