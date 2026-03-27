import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's check-in at a spot (stored in top-level `spotCheckIns/{checkInId}`).
class SpotCheckIn {
  const SpotCheckIn({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.checkedInAt,
    required this.expectedEndAt,
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

  /// Until when the user expects to be (or was) at the spot, for "here now" presence.
  final DateTime expectedEndAt;
  final bool isPrivate;

  /// Denormalized at write time for lists without extra spot reads.
  final String? spotName;
  final String? comment;
  final String? displayName;
  final String? photoURL;

  static const int maxCommentLength = 200;

  /// Whether this check-in counts as "currently here" at [now].
  bool isActiveAt(DateTime now) {
    return !now.isBefore(checkedInAt) && !now.isAfter(expectedEndAt);
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
    final endTs = data['expectedEndAt'];
    DateTime expectedEndAt;
    if (endTs is Timestamp) {
      expectedEndAt = endTs.toDate();
    } else {
      expectedEndAt = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return SpotCheckIn(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      spotId: data['spotId'] as String? ?? '',
      checkedInAt: at,
      expectedEndAt: expectedEndAt,
      isPrivate: data['isPrivate'] == true,
      spotName: data['spotName'] as String?,
      comment: data['comment'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }
}
