import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String? id;
  final String spotId;
  final String userId;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Rating({
    this.id,
    required this.spotId,
    required this.userId,
    required this.rating,
    this.createdAt,
    this.updatedAt,
  });

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      userId: data['userId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spotId': spotId,
      'userId': userId,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Rating copyWith({
    String? id,
    String? spotId,
    String? userId,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rating(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Rating(id: $id, spotId: $spotId, userId: $userId, rating: $rating)';
  }
}
