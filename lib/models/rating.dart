import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String? id;
  final String spotId;
  final String userId;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Denormalized from the rater's profile for public "who rated" UI.
  final String? displayName;

  /// Null when the profile is private or has no photo.
  final String? photoURL;

  Rating({
    this.id,
    required this.spotId,
    required this.userId,
    required this.rating,
    this.createdAt,
    this.updatedAt,
    this.displayName,
    this.photoURL,
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
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spotId': spotId,
      'userId': userId,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (displayName != null) 'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
    };
  }

  Rating copyWith({
    String? id,
    String? spotId,
    String? userId,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? displayName = _omit,
    Object? photoURL = _omit,
  }) {
    return Rating(
      id: id ?? this.id,
      spotId: spotId ?? this.spotId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName == _omit
          ? this.displayName
          : displayName as String?,
      photoURL: photoURL == _omit ? this.photoURL : photoURL as String?,
    );
  }

  @override
  String toString() {
    return 'Rating(id: $id, spotId: $spotId, userId: $userId, rating: $rating)';
  }
}

const Object _omit = Object();
