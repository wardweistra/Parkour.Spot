import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/event_interest.dart';
import '../models/parkour_event.dart';
import '../utils/event_interest_utils.dart';
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

  /// Going-wins status across [clusterEventIds] for the signed-in user.
  Stream<EventInterestStatus?> watchClusterInterest(
    Iterable<String> clusterEventIds,
  ) {
    final userId = _userId;
    final col = userId == null ? null : _interestsColFor(userId);
    final ids = clusterEventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (userId == null || col == null || ids.isEmpty) {
      return Stream<EventInterestStatus?>.value(null);
    }
    return col.snapshots().map((snap) {
      final interests = snap.docs
          .where((doc) => ids.contains(doc.id))
          .map((doc) => EventInterest.fromFirestore(doc, userId: userId));
      return clusterEventInterestStatus(interests);
    });
  }

  /// Native event id plus every listing marked as a duplicate of it.
  Future<Set<String>> getInterestClusterIds(ParkourEvent event) async {
    final ids = eventInterestClusterIds(event: event);
    final nativeId = canonicalEventInterestEventId(event);
    if (nativeId == null) return ids;
    try {
      final snap = await _firestore
          .collection('events')
          .where('duplicateOf', isEqualTo: nativeId)
          .get();
      for (final doc in snap.docs) {
        final id = doc.id.trim();
        if (id.isNotEmpty) ids.add(id);
      }
    } catch (e, st) {
      debugPrint('EventInterestService.getInterestClusterIds: $e\n$st');
    }
    return ids;
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
  ///
  /// Writes to [eventId] (the listing being viewed). Sibling docs in
  /// [clusterEventIds] are deleted so the user is counted once in the cluster.
  Future<bool> setInterest({
    required String eventId,
    required EventInterestStatus? status,
    DateTime? eventStartAt,
    Iterable<String>? clusterEventIds,
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

      final toDelete = eventInterestIdsToDelete(
        listingEventId: trimmed,
        clusterEventIds: clusterEventIds ?? const <String>[],
        nextStatus: status,
      );
      final batch = _firestore.batch();
      if (status == null) {
        for (final id in toDelete) {
          batch.delete(col.doc(id));
        }
      } else {
        final ref = col.doc(trimmed);
        final existing = await ref.get();
        if (existing.exists) {
          batch.update(ref, {
            'status': status.wireValue,
            'updatedAt': FieldValue.serverTimestamp(),
            if (eventStartAt != null)
              'eventStartAt': Timestamp.fromDate(eventStartAt.toUtc()),
          });
        } else {
          batch.set(ref, {
            'userId': userId,
            'eventId': trimmed,
            'status': status.wireValue,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (eventStartAt != null)
              'eventStartAt': Timestamp.fromDate(eventStartAt.toUtc()),
          });
        }
        for (final id in toDelete) {
          batch.delete(col.doc(id));
        }
      }
      await batch.commit();

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
