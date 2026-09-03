import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/event_interest.dart';
import '../models/parkour_event.dart';
import 'auth_service.dart';

/// Reads and writes event RSVPs (`users/{uid}/eventInterests/{eventId}`).
class EventInterestService extends ChangeNotifier {
  EventInterestService(this._authService, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final FirebaseFirestore _firestore;

  static const int _inQueryLimit = 30;

  String? _error;
  bool _isSaving = false;

  String? get error => _error;
  bool get isSaving => _isSaving;

  String? get _userId => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _interestsColFor(String userId) {
    if (userId.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('eventInterests');
  }

  DocumentReference<Map<String, dynamic>> _statsRef(String eventId) {
    return _firestore.collection('eventInterestStats').doc(eventId);
  }

  Stream<EventInterestStats> watchStats(String eventId) {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty) {
      return Stream<EventInterestStats>.value(EventInterestStats.empty);
    }
    return _statsRef(trimmed).snapshots().map(EventInterestStats.fromFirestore);
  }

  Stream<EventInterest?> watchUserInterest(String eventId) {
    final userId = _userId;
    final trimmed = eventId.trim();
    final col = userId == null ? null : _interestsColFor(userId);
    if (userId == null || col == null || trimmed.isEmpty) {
      return Stream<EventInterest?>.value(null);
    }
    return col.doc(trimmed).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventInterest.fromFirestore(doc, userId: userId);
    });
  }

  Future<List<EventInterest>> getMyInterests() async {
    final userId = _userId;
    final col = userId == null ? null : _interestsColFor(userId);
    if (userId == null || col == null) return const [];
    final snap = await col.get();
    return snap.docs
        .map((doc) => EventInterest.fromFirestore(doc, userId: userId))
        .toList(growable: false);
  }

  Future<Map<String, ParkourEvent>> getEventsByIds(Iterable<String> ids) async {
    final unique = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (unique.isEmpty) return const {};

    final result = <String, ParkourEvent>{};
    for (var i = 0; i < unique.length; i += _inQueryLimit) {
      final end = (i + _inQueryLimit) < unique.length
          ? i + _inQueryLimit
          : unique.length;
      final chunk = unique.sublist(i, end);
      final snap = await _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = ParkourEvent.fromFirestore(doc);
      }
    }
    return result;
  }

  /// Sets or clears the signed-in user's interest. [status] null removes it.
  Future<bool> setInterest({
    required String eventId,
    required EventInterestStatus? status,
    DateTime? eventStartAt,
  }) async {
    final userId = _userId;
    final trimmed = eventId.trim();
    final col = userId == null ? null : _interestsColFor(userId);
    if (userId == null || col == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }
    if (trimmed.isEmpty) {
      _error = 'Invalid event';
      notifyListeners();
      return false;
    }

    try {
      _isSaving = true;
      _error = null;
      notifyListeners();

      final ref = col.doc(trimmed);
      if (status == null) {
        await ref.delete();
      } else {
        final existing = await ref.get();
        if (existing.exists) {
          await ref.update({
            'status': status.wireValue,
            'updatedAt': FieldValue.serverTimestamp(),
            if (eventStartAt != null)
              'eventStartAt': Timestamp.fromDate(eventStartAt.toUtc()),
          });
        } else {
          await ref.set({
            'userId': userId,
            'eventId': trimmed,
            'status': status.wireValue,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (eventStartAt != null)
              'eventStartAt': Timestamp.fromDate(eventStartAt.toUtc()),
          });
        }
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('EventInterestService.setInterest: $e\n$st');
      _error = 'Could not update your interest';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
