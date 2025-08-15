import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String? id;
  final String name;
  final String description;
  final GeoPoint location;
  final String? imageUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? rating;
  final int? ratingCount;
  final List<String>? tags;
  final bool? isPublic;

  Spot({
    this.id,
    required this.name,
    required this.description,
    required this.location,
    this.imageUrl,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.rating,
    this.ratingCount,
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
      imageUrl: data['imageUrl'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'rating': rating,
      'ratingCount': ratingCount,
      'tags': tags,
      'isPublic': isPublic,
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    String? description,
    GeoPoint? location,
    String? imageUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? ratingCount,
    List<String>? tags,
    bool? isPublic,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  String toString() {
    return 'Spot(id: $id, name: $name, description: $description, location: $location)';
  }
}
