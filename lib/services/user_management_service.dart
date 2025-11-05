import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart' as app_user;

/// Simple immutable data class representing aggregate statistics for a user.
class UserStats {
  const UserStats({required this.spotReports, required this.ratings});

  /// Number of spot reports submitted by the user.
  final int spotReports;

  /// Number of ratings submitted by the user.
  final int ratings;
}

/// Service responsible for loading admin-facing user information and actions.
class UserManagementService extends ChangeNotifier {
  UserManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final List<app_user.User> _users = <app_user.User>[];
  bool _isLoading = false;
  String? _error;

  final Map<String, UserStats> _statsCache = <String, UserStats>{};
  final Map<String, String> _statsErrors = <String, String>{};
  final Set<String> _loadingStatsFor = <String>{};
  final Set<String> _updatingModeratorFor = <String>{};

  /// Unmodifiable list of all loaded users.
  List<app_user.User> get users => List<app_user.User>.unmodifiable(_users);

  /// Indicates whether the service is currently loading the user list.
  bool get isLoading => _isLoading;

  /// Returns the latest error message for list loading operations, if present.
  String? get error => _error;

  /// Returns an error message associated with stats loading for the given user.
  String? statsError(String userId) => _statsErrors[userId];

  /// Whether the service is currently loading statistics for the given user.
  bool isLoadingStats(String userId) => _loadingStatsFor.contains(userId);

  /// Whether the service is currently updating moderator status for the user.
  bool isUpdatingModerator(String userId) => _updatingModeratorFor.contains(userId);

  /// Returns cached statistics for the given user if available.
  UserStats? getStats(String userId) => _statsCache[userId];

  /// Loads the most recent set of users from Firestore.
  Future<void> fetchUsers({bool forceRefresh = false, int limit = 200}) async {
    if (_isLoading && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('email')
          .limit(limit)
          .get();

      _users
        ..clear()
        ..addAll(querySnapshot.docs.map((doc) {
          final data = doc.data();
          return app_user.User.fromMap(<String, dynamic>{
            'id': doc.id,
            ...data,
          });
        }));
    } catch (e, stackTrace) {
      _error = 'Failed to load users';
      debugPrint('UserManagementService.fetchUsers error: $e');
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ensures statistics for the provided user are loaded and cached.
  Future<UserStats?> loadUserStats(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _statsCache.containsKey(userId)) {
      return _statsCache[userId];
    }
    if (_loadingStatsFor.contains(userId)) {
      return _statsCache[userId];
    }

    _loadingStatsFor.add(userId);
    _statsErrors.remove(userId);
    notifyListeners();

    try {
      final int reportedCount = await _countDocuments(
        _firestore.collection('spotReports').where('reporterUserId', isEqualTo: userId),
      );
      final int ratingsCount = await _countDocuments(
        _firestore.collection('ratings').where('userId', isEqualTo: userId),
      );

      final stats = UserStats(spotReports: reportedCount, ratings: ratingsCount);
      _statsCache[userId] = stats;
      return stats;
    } catch (e, stackTrace) {
      debugPrint('UserManagementService.loadUserStats error for $userId: $e');
      debugPrint('$stackTrace');
      _statsErrors[userId] = 'Unable to load statistics';
      return null;
    } finally {
      _loadingStatsFor.remove(userId);
      notifyListeners();
    }
  }

  /// Toggles moderator status and updates internal cache.
  Future<bool> updateModeratorStatus(String userId, bool isModerator) async {
    if (_updatingModeratorFor.contains(userId)) {
      return false;
    }

    _updatingModeratorFor.add(userId);
    notifyListeners();

    try {
      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'isModerator': isModerator,
      });

      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isModerator: isModerator);
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('UserManagementService.updateModeratorStatus error: $e');
      debugPrint('$stackTrace');
      return false;
    } finally {
      _updatingModeratorFor.remove(userId);
      notifyListeners();
    }
  }

  Future<int> _countDocuments(Query<Map<String, dynamic>> query) async {
    try {
      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Firestore requires an index; fall back to client-side count.
        final snapshot = await query.get();
        return snapshot.docs.length;
      }
      rethrow;
    }
  }
}
