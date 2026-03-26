import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/spot_tracking_service.dart';

class SpotCheckInService extends ChangeNotifier {
  SpotCheckInService(this._authService, this._trackingService);

  final AuthService _authService;
  final SpotTrackingService _trackingService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _getCurrentUserId() => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _checkInsCol(String spotId) {
    return _firestore.collection('spots').doc(spotId).collection('checkIns');
  }

  /// Adds / updates check-in and ensures the spot is on "Been to" and off "Want to visit".
  Future<bool> checkIn(
    String spotId, {
    required bool isPrivate,
    String? comment,
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

      await _checkInsCol(spotId).doc(userId).set({
        'userId': userId,
        'checkedInAt': FieldValue.serverTimestamp(),
        'isPrivate': isPrivate,
        if (commentOut != null)
          'comment': commentOut
        else
          'comment': FieldValue.delete(),
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
      }, SetOptions(merge: true));

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

  /// Public check-ins in the last hour (visible to everyone).
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
        sub = _checkInsCol(spotId)
            .where('isPrivate', isEqualTo: false)
            .where('checkedInAt', isGreaterThan: threshold)
            .orderBy('checkedInAt', descending: true)
            .snapshots()
            .listen((snap) {
              final now = DateTime.now();
              final list = snap.docs
                  .map(SpotCheckIn.fromFirestore)
                  .where((c) => c.isActiveAt(now))
                  .toList();
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

  /// Current user's check-in doc (for private indicator). Null if signed out.
  Stream<SpotCheckIn?> watchMyCheckIn(String spotId) {
    final userId = _getCurrentUserId();
    if (userId == null) {
      return Stream.value(null);
    }
    return _checkInsCol(spotId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final checkIn = SpotCheckIn.fromFirestore(doc);
      if (!checkIn.isActiveAt(DateTime.now())) return null;
      return checkIn;
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
