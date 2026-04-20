import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/utils/check_in_time.dart';
import 'package:parkour_spot/services/spot_tracking_service.dart';

/// One page of the current user's check-in history (newest first).
class SpotCheckInsPage {
  const SpotCheckInsPage({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  static const SpotCheckInsPage empty = SpotCheckInsPage(
    items: [],
    hasMore: false,
  );

  final List<SpotCheckIn> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class SpotCheckInService extends ChangeNotifier {
  SpotCheckInService(this._authService, this._trackingService);

  final AuthService _authService;
  final SpotTrackingService _trackingService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int myCheckInsPageSize = 25;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _getCurrentUserId() => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _spotCheckInsCol =>
      _firestore.collection('spotCheckIns');

  CollectionReference<Map<String, dynamic>> get _spotTrainingPlansCol =>
      _firestore.collection('spotTrainingPlans');

  /// Adds a new check-in record and ensures the spot is on "Been to" and off "Want to visit".
  ///
  /// When [consumeTrainingPlanId] is set, deletes that training plan in the same batch
  /// and stores [convertedFromTrainingPlanId] plus a snapshot of the plan (start/end/comment/createdAt).
  Future<bool> checkIn(
    String spotId, {
    required bool isPrivate,
    required DateTime expectedEndAt,
    String? comment,
    String? spotName,
    String? consumeTrainingPlanId,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }
    if (spotId.isEmpty) {
      _error = 'Invalid spot';
      notifyListeners();
      return false;
    }

    final endUtc = expectedEndAt.toUtc();
    final nowUtc = DateTime.now().toUtc();
    if (!endUtc.isAfter(nowUtc)) {
      _error = 'End time must be after now';
      notifyListeners();
      return false;
    }
    final maxEnd = nowUtc.add(SpotCheckIn.maxSessionDuration);
    if (endUtc.isAfter(maxEnd)) {
      _error = 'End time is too far in the future';
      notifyListeners();
      return false;
    }

    final trimmed = comment?.trim();
    final commentOut = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (commentOut != null &&
        commentOut.length > SpotCheckIn.maxCommentLength) {
      _error = 'Comment is too long';
      notifyListeners();
      return false;
    }

    final profile = _authService.userProfile;
    final displayName =
        profile?.displayName ?? _authService.currentUser?.displayName;
    final photoURL = profile?.photoURL ?? _authService.currentUser?.photoURL;

    String? consumeId = consumeTrainingPlanId?.trim();
    if (consumeId != null && consumeId.isEmpty) consumeId = null;

    SpotTrainingPlan? consumedPlan;
    if (consumeId != null) {
      final planSnap = await _spotTrainingPlansCol.doc(consumeId).get();
      if (!planSnap.exists) {
        _error = 'Training plan not found';
        notifyListeners();
        return false;
      }
      final plan = SpotTrainingPlan.fromFirestore(planSnap);
      if (plan.userId != userId || plan.spotId != spotId) {
        _error = 'Invalid training plan';
        notifyListeners();
        return false;
      }
      if (!trainingPlanEligibleForLinkedCheckIn(plan, DateTime.now())) {
        _error = 'Training plan is no longer valid for check-in';
        notifyListeners();
        return false;
      }
      consumedPlan = plan;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final visitedOk = await _trackingService.addToVisited(spotId);
      if (!visitedOk) {
        _error = _trackingService.error ?? 'Failed to update your lists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newRef = _spotCheckInsCol.doc();
      final payload = <String, dynamic>{
        'userId': userId,
        'spotId': spotId,
        'checkedInAt': FieldValue.serverTimestamp(),
        'expectedEndAt': Timestamp.fromDate(expectedEndAt),
        'isPrivate': isPrivate,
        if (commentOut != null) 'comment': commentOut,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (spotName != null && spotName.trim().isNotEmpty)
          'spotName': spotName.trim(),
      };
      if (consumeId != null && consumedPlan != null) {
        payload['convertedFromTrainingPlanId'] = consumeId;
        payload['convertedPlanPlannedStartAt'] =
            Timestamp.fromDate(consumedPlan.plannedStartAt);
        payload['convertedPlanPlannedEndAt'] =
            Timestamp.fromDate(consumedPlan.plannedEndAt);
        final planComment = consumedPlan.comment?.trim();
        if (planComment != null && planComment.isNotEmpty) {
          payload['convertedPlanComment'] = planComment;
        }
        final createdAt = consumedPlan.createdAt;
        if (createdAt != null) {
          payload['convertedPlanCreatedAt'] = Timestamp.fromDate(createdAt);
        }
      }

      if (consumeId != null) {
        final batch = _firestore.batch();
        batch.set(newRef, payload);
        batch.delete(_spotTrainingPlansCol.doc(consumeId));
        await batch.commit();
      } else {
        await newRef.set(payload);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Check-in failed: $e';
      debugPrint('Spot check-in error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing check-in owned by the current user (start, end, privacy, comment).
  Future<bool> updateCheckIn(
    String checkInId, {
    required DateTime checkedInAt,
    required bool isPrivate,
    required DateTime expectedEndAt,
    String? comment,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }
    if (checkInId.isEmpty) return false;

    final startUtc = checkedInAt.toUtc();
    final endUtc = expectedEndAt.toUtc();
    final nowUtc = DateTime.now().toUtc();
    if (!startUtc.isBefore(endUtc)) {
      _error = 'End time must be after start time';
      notifyListeners();
      return false;
    }
    final dur = endUtc.difference(startUtc);
    if (dur > SpotCheckIn.maxSessionDuration) {
      _error = 'Session cannot be longer than 12 hours';
      notifyListeners();
      return false;
    }
    if (startUtc.isAfter(nowUtc)) {
      _error = 'Start time cannot be in the future';
      notifyListeners();
      return false;
    }

    final trimmed = comment?.trim();
    final commentOut = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (commentOut != null &&
        commentOut.length > SpotCheckIn.maxCommentLength) {
      _error = 'Comment is too long';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final update = <String, dynamic>{
        'checkedInAt': Timestamp.fromDate(checkedInAt),
        'expectedEndAt': Timestamp.fromDate(expectedEndAt),
        'isPrivate': isPrivate,
      };
      if (commentOut != null) {
        update['comment'] = commentOut;
      } else {
        update['comment'] = FieldValue.delete();
      }

      await _spotCheckInsCol.doc(checkInId).update(update);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not update check-in: $e';
      debugPrint('updateCheckIn error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Deletes a check-in document owned by the current user.
  Future<bool> deleteCheckIn(String checkInId) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }
    if (checkInId.isEmpty) return false;
    try {
      _error = null;
      await _spotCheckInsCol.doc(checkInId).delete();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not delete check-in: $e';
      debugPrint('deleteCheckIn error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Active check-ins for the current user at spots other than [excludeSpotId].
  ///
  /// Uses `expectedEndAt >= now` plus [SpotCheckIn.isActiveAt] so we only consider
  /// sessions that are still “here now” by app rules.
  ///
  /// Returns `null` if the query fails ([error] is set).
  Future<List<SpotCheckIn>?> fetchActiveCheckInsElsewhere(
    String excludeSpotId,
  ) async {
    final userId = _getCurrentUserId();
    if (userId == null || excludeSpotId.isEmpty) {
      return [];
    }
    final now = DateTime.now();
    final threshold = Timestamp.fromDate(now);
    try {
      final snap = await _spotCheckInsCol
          .where('userId', isEqualTo: userId)
          .where('expectedEndAt', isGreaterThanOrEqualTo: threshold)
          .orderBy('expectedEndAt', descending: true)
          .limit(_presenceQueryLimit)
          .get();
      final out = <SpotCheckIn>[];
      for (final doc in snap.docs) {
        final c = SpotCheckIn.fromFirestore(doc);
        if (c.spotId == excludeSpotId) continue;
        if (!c.isActiveAt(now)) continue;
        out.add(c);
      }
      return out;
    } catch (e) {
      _error = 'Could not verify your other check-ins';
      debugPrint('fetchActiveCheckInsElsewhere error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Whether [c] is the current user's most recent check-in (by [checkedInAt]).
  ///
  /// Used so “extend / still here” only applies when the user has no newer check-in
  /// at another spot (one active session narrative).
  Future<bool> isUsersLatestCheckIn(SpotCheckIn c) async {
    final userId = _getCurrentUserId();
    if (userId == null || c.userId != userId) return false;
    try {
      final snap = await _spotCheckInsCol
          .where('userId', isEqualTo: userId)
          .orderBy('checkedInAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;
      return snap.docs.single.id == c.id;
    } catch (e) {
      debugPrint('isUsersLatestCheckIn error: $e');
      return false;
    }
  }

  /// “Still here” / extend UI: [SpotCheckIn.stillHereEligibleAt] and [c] must be
  /// the user’s latest check-in globally.
  Future<bool> stillHereEligibleForUser(SpotCheckIn c) async {
    final now = DateTime.now();
    if (!c.stillHereEligibleAt(now)) return false;
    return isUsersLatestCheckIn(c);
  }

  /// User’s latest check-in if it is at [spotId], no longer active, and extendable
  /// ([SpotCheckIn.stillHereEligibleAt]) — for new check-in UX without duplicate docs.
  ///
  /// Requires this check-in to be the user’s most recent (same query as
  /// [isUsersLatestCheckIn]) so we don’t offer extend after a newer check-in elsewhere.
  ///
  /// Returns `null` if none, or on query failure (non-blocking; does not set [error]).
  Future<SpotCheckIn?> fetchExtendableCheckInAtSpot(String spotId) async {
    final userId = _getCurrentUserId();
    if (userId == null || spotId.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    try {
      final snap = await _spotCheckInsCol
          .where('userId', isEqualTo: userId)
          .orderBy('checkedInAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final c = SpotCheckIn.fromFirestore(snap.docs.single);
      if (c.spotId != spotId) return null;
      if (c.isActiveAt(now)) return null;
      if (!c.stillHereEligibleAt(now)) return null;
      return c;
    } catch (e) {
      debugPrint('fetchExtendableCheckInAtSpot error: $e');
      return null;
    }
  }

  /// Sets [expectedEndAt] to now (or just after [checkedInAt] if needed) for an
  /// existing check-in owned by the current user.
  Future<bool> endCheckInNow(SpotCheckIn c) async {
    final now = DateTime.now();
    final end =
        now.isAfter(c.checkedInAt) ? now : c.checkedInAt.add(const Duration(seconds: 1));
    return updateCheckIn(
      c.id,
      checkedInAt: c.checkedInAt,
      isPrivate: c.isPrivate,
      expectedEndAt: end,
      comment: c.comment,
    );
  }

  /// Paginated history for the signed-in user (newest first).
  Future<SpotCheckInsPage> fetchMyCheckInsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return SpotCheckInsPage.empty;
    }
    Query<Map<String, dynamic>> q = _spotCheckInsCol
        .where('userId', isEqualTo: userId)
        .orderBy('checkedInAt', descending: true)
        .limit(myCheckInsPageSize);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.get();
    final items = snap.docs.map(SpotCheckIn.fromFirestore).toList();
    final last = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length == myCheckInsPageSize;
    return SpotCheckInsPage(items: items, lastDocument: last, hasMore: hasMore);
  }

  static List<SpotCheckIn> _dedupePublicByUserNewestFirst(
    List<SpotCheckIn> raw,
    DateTime now,
  ) {
    final byUser = <String, SpotCheckIn>{};
    for (final c in raw) {
      if (!c.isActiveAt(now)) continue;
      final existing = byUser[c.userId];
      if (existing == null || c.checkedInAt.isAfter(existing.checkedInAt)) {
        byUser[c.userId] = c;
      }
    }
    final list = byUser.values.toList()
      ..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt));
    return list;
  }

  static const int _presenceQueryLimit = 100;

  /// Public check-ins still within their expected end time (visible to everyone), one per user.
  ///
  /// Re-attaches periodically so the rolling [expectedEndAt] threshold stays accurate.
  Stream<List<SpotCheckIn>> watchPublicCheckIns(String spotId) {
    return Stream<List<SpotCheckIn>>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      Timer? timer;

      void attach() {
        sub?.cancel();
        final now = DateTime.now();
        final threshold = Timestamp.fromDate(now);
        sub = _spotCheckInsCol
            .where('spotId', isEqualTo: spotId)
            .where('isPrivate', isEqualTo: false)
            .where('expectedEndAt', isGreaterThanOrEqualTo: threshold)
            .orderBy('expectedEndAt', descending: true)
            .limit(_presenceQueryLimit)
            .snapshots()
            .listen((snap) {
              final nowInner = DateTime.now();
              final raw = snap.docs.map(SpotCheckIn.fromFirestore).toList();
              final list = _dedupePublicByUserNewestFirst(raw, nowInner);
              controller.add(list);
            }, onError: controller.addError);
      }

      attach();
      timer = Timer.periodic(const Duration(minutes: 1), (_) => attach());

      controller.onCancel = () {
        timer?.cancel();
        sub?.cancel();
      };
    });
  }

  /// Current user's latest active check-in at this spot (for private indicator).
  Stream<SpotCheckIn?> watchMyCheckIn(String spotId) {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return Stream.value(null);
    }
    return Stream<SpotCheckIn?>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      Timer? timer;

      void attach() {
        sub?.cancel();
        final now = DateTime.now();
        final threshold = Timestamp.fromDate(now);
        sub = _spotCheckInsCol
            .where('spotId', isEqualTo: spotId)
            .where('userId', isEqualTo: userId)
            .where('expectedEndAt', isGreaterThanOrEqualTo: threshold)
            .orderBy('expectedEndAt', descending: true)
            .limit(_presenceQueryLimit)
            .snapshots()
            .listen((snap) {
              final nowInner = DateTime.now();
              if (snap.docs.isEmpty) {
                controller.add(null);
                return;
              }
              final candidates =
                  snap.docs.map(SpotCheckIn.fromFirestore).toList();
              SpotCheckIn? best;
              for (final c in candidates) {
                if (!c.isActiveAt(nowInner)) continue;
                if (best == null ||
                    c.checkedInAt.isAfter(best.checkedInAt)) {
                  best = c;
                }
              }
              controller.add(best);
            }, onError: controller.addError);
      }

      attach();
      timer = Timer.periodic(const Duration(minutes: 1), (_) => attach());

      controller.onCancel = () {
        timer?.cancel();
        sub?.cancel();
      };
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
