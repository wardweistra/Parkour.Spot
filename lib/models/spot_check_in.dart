import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's check-in at a spot (stored in top-level `spotCheckIns/{checkInId}`).
class SpotCheckIn {
  const SpotCheckIn({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.checkedInAt,
    required this.isPrivate,
    this.spotName,
    this.comment,
    this.displayName,
    this.photoURL,
  });

  /// Firestore document id.
  final String id;
  final String userId;
  final String spotId;
  final DateTime checkedInAt;
  final bool isPrivate;

  /// Denormalized at write time for lists without extra spot reads.
  final String? spotName;
  final String? comment;
  final String? displayName;
  final String? photoURL;

  static const Duration activeWindow = Duration(hours: 1);

  static const int maxCommentLength = 200;

  /// Whether this check-in is still within the "currently here" window.
  bool isActiveAt(DateTime now) {
    return now.difference(checkedInAt) <= activeWindow;
  }

  factory SpotCheckIn.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final ts = data['checkedInAt'];
    DateTime at;
    if (ts is Timestamp) {
      at = ts.toDate();
    } else {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return SpotCheckIn(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      spotId: data['spotId'] as String? ?? '',
      checkedInAt: at,
      isPrivate: data['isPrivate'] == true,
      spotName: data['spotName'] as String?,
      comment: data['comment'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }
}
