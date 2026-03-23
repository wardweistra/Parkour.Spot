import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_list.dart';
import '../services/auth_service.dart';
import '../services/spot_list_service.dart';

/// Bookmarks of other users' spot lists under `users/{uid}/savedSpotLists/{listId}`.
/// Available to all signed-in users (not gated on the `spotLists` feature flag).
class SavedSpotListService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  SavedSpotListService(this._authService);

  String? _getCurrentUserId() {
    return _authService.currentUser?.uid;
  }

  CollectionReference<Map<String, dynamic>>? _savedRef() {
    final userId = _getCurrentUserId();
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedSpotLists');
  }

  /// Signed-in users can save others' lists (no `spotLists` feature flag).
  bool canUseSavedSpotLists() {
    return _authService.isAuthenticated;
  }

  Future<bool> saveList(String listId) async {
    if (!_authService.isAuthenticated) {
      _error = 'You must be signed in to save a list';
      notifyListeners();
      return false;
    }
    if (listId.isEmpty) {
      _error = 'Invalid list';
      notifyListeners();
      return false;
    }

    final ref = _savedRef();
    if (ref == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await ref.doc(listId).set({'savedAt': FieldValue.serverTimestamp()});

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save list: $e';
      debugPrint('Error saving spot list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unsaveList(String listId) async {
    if (!_authService.isAuthenticated) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }

    final ref = _savedRef();
    if (ref == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await ref.doc(listId).delete();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove list: $e';
      debugPrint('Error unsaving spot list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Live subscription for whether [listId] is in the user's saved lists.
  Stream<bool> watchIsSaved(String listId) {
    final ref = _savedRef();
    if (ref == null || listId.isEmpty) {
      return Stream.value(false);
    }
    return ref.doc(listId).snapshots().map((s) => s.exists);
  }

  /// Ordered saved list IDs (newest first). Empty stream list when signed out.
  Stream<List<String>> watchSavedListIdsOrdered() {
    final ref = _savedRef();
    if (ref == null) {
      return Stream.value([]);
    }
    return ref
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Resolve bookmark IDs to [SpotList]s the user can still read (skips missing/private).
  Future<List<SpotList>> resolveSavedListIds(
    SpotListService spotListService,
    List<String> listIds,
  ) async {
    final result = <SpotList>[];
    for (final id in listIds) {
      final list = await spotListService.getSpotListById(id);
      if (list != null) {
        result.add(list);
      }
    }
    return result;
  }

  /// One-shot load from Firestore (e.g. pull-to-refresh).
  Future<List<SpotList>> loadResolvedSavedLists(
    SpotListService spotListService,
  ) async {
    final ref = _savedRef();
    if (ref == null) return [];

    try {
      final snap = await ref.orderBy('savedAt', descending: true).get();
      final ids = snap.docs.map((d) => d.id).toList();
      return resolveSavedListIds(spotListService, ids);
    } catch (e) {
      debugPrint('Error loading saved spot lists: $e');
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
