import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's check-in at a spot (stored under `spots/{spotId}/checkIns/{userId}`).
class SpotCheckIn {
  const SpotCheckIn({
    required this.userId,
    required this.checkedInAt,
    required this.isPrivate,
    this.comment,
    this.displayName,
    this.photoURL,
  });

  final String userId;
  final DateTime checkedInAt;
  final bool isPrivate;
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
      userId: data['userId'] as String? ?? doc.id,
      checkedInAt: at,
      isPrivate: data['isPrivate'] == true,
      comment: data['comment'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }
}
