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
    this.convertedFromTrainingPlanId,
    this.convertedPlanPlannedStartAt,
    this.convertedPlanPlannedEndAt,
    this.convertedPlanComment,
    this.convertedPlanCreatedAt,
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

  /// Set when this check-in replaced a training plan document.
  final String? convertedFromTrainingPlanId;

  /// Snapshot of the plan at conversion (plan doc is deleted after consume).
  final DateTime? convertedPlanPlannedStartAt;
  final DateTime? convertedPlanPlannedEndAt;
  final String? convertedPlanComment;
  final DateTime? convertedPlanCreatedAt;

  static const int maxCommentLength = 200;

  /// Maximum allowed length for a "here until" session when checking in (client + rules).
  static const Duration maxSessionDuration = Duration(hours: 12);

  /// Whether this check-in counts as "currently here" at [now].
  bool isActiveAt(DateTime now) {
    return !now.isBefore(checkedInAt) && !now.isAfter(expectedEndAt);
  }

  /// Time-window only: scheduled end has passed, but arrival was within [maxSessionDuration].
  ///
  /// UI and [SpotCheckInService.stillHereEligibleForUser] also require this to be the
  /// user’s latest check-in so we keep one session at a time.
  bool stillHereEligibleAt(DateTime now) {
    if (now.isBefore(checkedInAt)) return false;
    if (!expectedEndAt.isBefore(now)) return false;
    return now.difference(checkedInAt) <= maxSessionDuration;
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
    DateTime? readOpt(String key) {
      final t = data[key];
      if (t is Timestamp) return t.toDate();
      return null;
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
      convertedFromTrainingPlanId:
          data['convertedFromTrainingPlanId'] as String?,
      convertedPlanPlannedStartAt: readOpt('convertedPlanPlannedStartAt'),
      convertedPlanPlannedEndAt: readOpt('convertedPlanPlannedEndAt'),
      convertedPlanComment: data['convertedPlanComment'] as String?,
      convertedPlanCreatedAt: readOpt('convertedPlanCreatedAt'),
    );
  }
}
