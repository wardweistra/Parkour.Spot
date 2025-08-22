import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String? id;
  final String name;
  final String description;
  final GeoPoint location;
  final List<String>? imageUrls;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? tags;
  final bool? isPublic;

  Spot({
    this.id,
    required this.name,
    required this.description,
    required this.location,
    this.imageUrls,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.tags,
    this.isPublic = true,
  });

  factory Spot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Spot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl']] : null),
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'imageUrls': imageUrls,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'tags': tags,
      'isPublic': isPublic,
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    String? description,
    GeoPoint? location,
    List<String>? imageUrls,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPublic,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrls: imageUrls ?? this.imageUrls,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  String toString() {
    return 'Spot(id: $id, name: $name, description: $description, location: $location)';
  }
}
