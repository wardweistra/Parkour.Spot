import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/utils/spot_training_plan_validation.dart';

class SpotTrainingPlanService extends ChangeNotifier {
  SpotTrainingPlanService(this._authService);

  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('spotTrainingPlans');

  String? _getCurrentUserId() => _authService.currentUser?.uid;

  static const int _queryLimit = 100;

  String? _validateInputs({
    required DateTime plannedStartAt,
    required DateTime plannedEndAt,
    required bool requireEndInFuture,
  }) {
    return SpotTrainingPlanValidation.validateWindow(
      plannedStartAt: plannedStartAt,
      plannedEndAt: plannedEndAt,
      now: DateTime.now(),
      requireEndInFuture: requireEndInFuture,
    );
  }

  /// Creates or updates the user’s single upcoming plan at [spotId].
  Future<bool> upsertPlan({
    required String spotId,
    required DateTime plannedStartAt,
    required DateTime plannedEndAt,
    required bool isPrivate,
    String? comment,
    String? spotName,
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

    final code = _validateInputs(
      plannedStartAt: plannedStartAt,
      plannedEndAt: plannedEndAt,
      requireEndInFuture: true,
    );
    if (code != null) {
      _error = _messageForCode(code);
      notifyListeners();
      return false;
    }

    final trimmed = comment?.trim();
    final commentOut = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (commentOut != null && commentOut.length > SpotTrainingPlan.maxCommentLength) {
      _error = 'Comment is too long';
      notifyListeners();
      return false;
    }

    final profile = _authService.userProfile;
    final displayName =
        profile?.displayName ?? _authService.currentUser?.displayName;
    final photoURL = profile?.photoURL ?? _authService.currentUser?.photoURL;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final threshold = Timestamp.fromDate(now);
      final existing = await _col
          .where('userId', isEqualTo: userId)
          .where('spotId', isEqualTo: spotId)
          .where('plannedEndAt', isGreaterThanOrEqualTo: threshold)
          .orderBy('plannedEndAt', descending: true)
          .limit(1)
          .get();

      final payloadBase = <String, dynamic>{
        'plannedStartAt': Timestamp.fromDate(plannedStartAt),
        'plannedEndAt': Timestamp.fromDate(plannedEndAt),
        'isPrivate': isPrivate,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (spotName != null && spotName.trim().isNotEmpty)
          'spotName': spotName.trim(),
      };
      if (commentOut != null) {
        payloadBase['comment'] = commentOut;
      }

      if (existing.docs.isEmpty) {
        await _col.add({
          ...payloadBase,
          'userId': userId,
          'spotId': spotId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final update = Map<String, dynamic>.from(payloadBase);
        if (commentOut == null) {
          update['comment'] = FieldValue.delete();
        }
        await existing.docs.single.reference.update(update);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not save plan: $e';
      debugPrint('upsertPlan error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'order':
        return 'End time must be after start time';
      case 'minDuration':
        return 'Window must be at least 15 minutes';
      case 'maxDuration':
        return 'Window cannot be longer than 12 hours';
      case 'startTooFar':
        return 'Start time cannot be more than 30 days away';
      case 'endNotFuture':
        return 'End time must be in the future';
      default:
        return 'Invalid time range';
    }
  }

  /// Latest upcoming plan for the current user at [spotId], if any.
  Future<SpotTrainingPlan?> fetchMyActivePlanAtSpot(String spotId) async {
    final userId = _getCurrentUserId();
    if (userId == null || spotId.isEmpty) return null;
    final now = DateTime.now();
    try {
      final snap = await _col
          .where('spotId', isEqualTo: spotId)
          .where('userId', isEqualTo: userId)
          .where('plannedEndAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('plannedEndAt', descending: true)
          .limit(_queryLimit)
          .get();
      SpotTrainingPlan? best;
      for (final doc in snap.docs) {
        final p = SpotTrainingPlan.fromFirestore(doc);
        if (!p.isUpcomingAt(now)) continue;
        if (best == null || p.plannedStartAt.isAfter(best.plannedStartAt)) {
          best = p;
        }
      }
      return best;
    } catch (e) {
      debugPrint('fetchMyActivePlanAtSpot error: $e');
      return null;
    }
  }

  Future<bool> deletePlan(String planId) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }
    if (planId.isEmpty) return false;
    try {
      _error = null;
      await _col.doc(planId).delete();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not remove plan: $e';
      debugPrint('deletePlan error: $e');
      notifyListeners();
      return false;
    }
  }

  static List<SpotTrainingPlan> _dedupePublicByUserNewestStart(
    List<SpotTrainingPlan> raw,
    DateTime now,
  ) {
    final byUser = <String, SpotTrainingPlan>{};
    for (final p in raw) {
      if (!p.isUpcomingAt(now)) continue;
      final existing = byUser[p.userId];
      if (existing == null ||
          p.plannedStartAt.isAfter(existing.plannedStartAt)) {
        byUser[p.userId] = p;
      }
    }
    final list = byUser.values.toList()
      ..sort((a, b) => b.plannedStartAt.compareTo(a.plannedStartAt));
    return list;
  }

  Stream<List<SpotTrainingPlan>> watchPublicPlansForSpot(String spotId) {
    return Stream<List<SpotTrainingPlan>>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      Timer? timer;

      void attach() {
        sub?.cancel();
        final now = DateTime.now();
        final threshold = Timestamp.fromDate(now);
        sub = _col
            .where('spotId', isEqualTo: spotId)
            .where('isPrivate', isEqualTo: false)
            .where('plannedEndAt', isGreaterThanOrEqualTo: threshold)
            .orderBy('plannedEndAt', descending: true)
            .limit(_queryLimit)
            .snapshots()
            .listen((snap) {
              final nowInner = DateTime.now();
              final raw =
                  snap.docs.map(SpotTrainingPlan.fromFirestore).toList();
              controller.add(_dedupePublicByUserNewestStart(raw, nowInner));
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

  Stream<SpotTrainingPlan?> watchMyPlanForSpot(String spotId) {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return Stream.value(null);
    }
    return Stream<SpotTrainingPlan?>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      Timer? timer;

      void attach() {
        sub?.cancel();
        final now = DateTime.now();
        final threshold = Timestamp.fromDate(now);
        sub = _col
            .where('spotId', isEqualTo: spotId)
            .where('userId', isEqualTo: userId)
            .where('plannedEndAt', isGreaterThanOrEqualTo: threshold)
            .orderBy('plannedEndAt', descending: true)
            .limit(_queryLimit)
            .snapshots()
            .listen((snap) {
              final nowInner = DateTime.now();
              if (snap.docs.isEmpty) {
                controller.add(null);
                return;
              }
              final candidates =
                  snap.docs.map(SpotTrainingPlan.fromFirestore).toList();
              SpotTrainingPlan? best;
              for (final p in candidates) {
                if (!p.isUpcomingAt(nowInner)) continue;
                if (best == null ||
                    p.plannedStartAt.isAfter(best.plannedStartAt)) {
                  best = p;
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
