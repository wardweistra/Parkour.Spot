import 'package:cloud_firestore/cloud_firestore.dart';

class SpotList {
  final String? id;
  final String name;
  final String? description;
  final List<String> spotIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SpotList({
    this.id,
    required this.name,
    this.description,
    required this.spotIds,
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
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpotList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      spotIds: spotIds ?? this.spotIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get spotCount => spotIds.length;

  @override
  String toString() {
    return 'SpotList(id: $id, name: $name, spotCount: $spotCount)';
  }
}

