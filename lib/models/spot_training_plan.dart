import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parkour_spot/models/spot_check_in.dart';

/// A user's planned training window at a spot (`spotTrainingPlans/{planId}`).
class SpotTrainingPlan {
  const SpotTrainingPlan({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.plannedStartAt,
    required this.plannedEndAt,
    required this.isPrivate,
    this.spotName,
    this.comment,
    this.displayName,
    this.photoURL,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String spotId;
  final DateTime plannedStartAt;
  final DateTime plannedEndAt;
  final bool isPrivate;

  final String? spotName;
  final String? comment;
  final String? displayName;
  final String? photoURL;

  /// When the plan was created (`createdAt` in Firestore), if present.
  final DateTime? createdAt;

  static const int maxCommentLength = 200;

  /// Same max session length as live check-ins.
  static Duration get maxWindowDuration => SpotCheckIn.maxSessionDuration;

  static const Duration minWindowDuration = Duration(minutes: 15);

  static const Duration maxAdvanceHorizon = Duration(days: 30);

  /// Plan still appears in “upcoming” lists ([plannedEndAt] not passed).
  bool isUpcomingAt(DateTime now) {
    return plannedEndAt.toUtc().isAfter(now.toUtc());
  }

  /// Whether [now] falls inside [plannedStartAt, plannedEndAt].
  bool contains(DateTime now) {
    final n = now.toUtc();
    final a = plannedStartAt.toUtc();
    final b = plannedEndAt.toUtc();
    return !n.isBefore(a) && !n.isAfter(b);
  }

  factory SpotTrainingPlan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    DateTime readTs(String key) {
      final ts = data[key];
      if (ts is Timestamp) return ts.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? readTsOptional(String key) {
      final ts = data[key];
      if (ts is Timestamp) return ts.toDate();
      return null;
    }

    return SpotTrainingPlan(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      spotId: data['spotId'] as String? ?? '',
      plannedStartAt: readTs('plannedStartAt'),
      plannedEndAt: readTs('plannedEndAt'),
      isPrivate: data['isPrivate'] == true,
      spotName: data['spotName'] as String?,
      comment: data['comment'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      createdAt: readTsOptional('createdAt'),
    );
  }
}
