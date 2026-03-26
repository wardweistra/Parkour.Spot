import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/services/auth_service.dart';
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

  /// Adds a new check-in record and ensures the spot is on "Been to" and off "Want to visit".
  Future<bool> checkIn(
    String spotId, {
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

      await _spotCheckInsCol.add({
        'userId': userId,
        'spotId': spotId,
        'checkedInAt': FieldValue.serverTimestamp(),
        'isPrivate': isPrivate,
        if (commentOut != null) 'comment': commentOut,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (spotName != null && spotName.trim().isNotEmpty)
          'spotName': spotName.trim(),
      });

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

  /// Public check-ins in the last hour (visible to everyone), one entry per user.
  ///
  /// Re-attaches the query periodically so the rolling one-hour window stays accurate.
  Stream<List<SpotCheckIn>> watchPublicCheckIns(String spotId) {
    return Stream<List<SpotCheckIn>>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      Timer? timer;

      void attach() {
        sub?.cancel();
        final cutoff = DateTime.now().subtract(SpotCheckIn.activeWindow);
        final threshold = Timestamp.fromDate(cutoff);
        sub = _spotCheckInsCol
            .where('spotId', isEqualTo: spotId)
            .where('isPrivate', isEqualTo: false)
            .where('checkedInAt', isGreaterThan: threshold)
            .orderBy('checkedInAt', descending: true)
            .snapshots()
            .listen((snap) {
              final now = DateTime.now();
              final raw = snap.docs.map(SpotCheckIn.fromFirestore).toList();
              final list = _dedupePublicByUserNewestFirst(raw, now);
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
        final cutoff = DateTime.now().subtract(SpotCheckIn.activeWindow);
        final threshold = Timestamp.fromDate(cutoff);
        sub = _spotCheckInsCol
            .where('spotId', isEqualTo: spotId)
            .where('userId', isEqualTo: userId)
            .where('checkedInAt', isGreaterThan: threshold)
            .orderBy('checkedInAt', descending: true)
            .limit(1)
            .snapshots()
            .listen((snap) {
              final now = DateTime.now();
              if (snap.docs.isEmpty) {
                controller.add(null);
                return;
              }
              final c = SpotCheckIn.fromFirestore(snap.docs.first);
              controller.add(c.isActiveAt(now) ? c : null);
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
