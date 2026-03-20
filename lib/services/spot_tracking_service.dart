import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class SpotTrackingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  SpotTrackingService(this._authService);

  String? _getCurrentUserId() {
    return _authService.currentUser?.uid;
  }

  /// Get want-to-visit spot IDs from the current user's profile
  List<String> getWantToVisit() {
    final profile = _authService.userProfile;
    return profile?.wantToVisit ?? [];
  }

  /// Get visited spot IDs from the current user's profile
  List<String> getVisited() {
    final profile = _authService.userProfile;
    return profile?.visited ?? [];
  }

  /// Add spot to want-to-visit. Removes from visited if present.
  Future<bool> addToWantToVisit(String spotId) async {
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

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update({
        'wantToVisit': FieldValue.arrayUnion([spotId]),
        'visited': FieldValue.arrayRemove([spotId]),
      });

      // Update local profile cache
      final wantToVisit = List<String>.from(getWantToVisit())..add(spotId);
      final visited = List<String>.from(getVisited())..remove(spotId);
      _authService.updateUserSpotTracking(wantToVisit: wantToVisit, visited: visited);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add: $e';
      debugPrint('Error adding to want to visit: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove spot from want-to-visit
  Future<bool> removeFromWantToVisit(String spotId) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update({
        'wantToVisit': FieldValue.arrayRemove([spotId]),
      });

      final wantToVisit = List<String>.from(getWantToVisit())..remove(spotId);
      _authService.updateUserSpotTracking(wantToVisit: wantToVisit, visited: getVisited());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove: $e';
      debugPrint('Error removing from want to visit: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add spot to visited. Removes from want-to-visit if present.
  Future<bool> addToVisited(String spotId) async {
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

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update({
        'visited': FieldValue.arrayUnion([spotId]),
        'wantToVisit': FieldValue.arrayRemove([spotId]),
      });

      final wantToVisit = List<String>.from(getWantToVisit())..remove(spotId);
      final visited = List<String>.from(getVisited())..add(spotId);
      _authService.updateUserSpotTracking(wantToVisit: wantToVisit, visited: visited);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add: $e';
      debugPrint('Error adding to visited: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove spot from visited
  Future<bool> removeFromVisited(String spotId) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'You must be signed in';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update({
        'visited': FieldValue.arrayRemove([spotId]),
      });

      final visited = List<String>.from(getVisited())..remove(spotId);
      _authService.updateUserSpotTracking(wantToVisit: getWantToVisit(), visited: visited);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove: $e';
      debugPrint('Error removing from visited: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
