import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart' as app_user;

/// Simple immutable data class representing aggregate statistics for a user.
class UserStats {
  const UserStats({
    required this.spotReports,
    required this.ratings,
    required this.spotsCreated,
  });

  /// Number of spot reports submitted by the user.
  final int spotReports;

  /// Number of ratings submitted by the user.
  final int ratings;

  /// Number of spots created by the user.
  final int spotsCreated;
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
  final Set<String> _updatingFeatureAccessFor = <String>{};
  bool _calculatingMetrics = false;
  String? _metricsError;
  Map<String, dynamic>? _lastMetricsResult;
  bool _syncingCreatedAt = false;
  String? _syncCreatedAtError;
  Map<String, dynamic>? _lastSyncCreatedAtResult;

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

  /// Whether the service is currently updating feature access for the user.
  bool isUpdatingFeatureAccess(String userId) => _updatingFeatureAccessFor.contains(userId);

  /// Whether the service is currently calculating user activity metrics.
  bool get isCalculatingMetrics => _calculatingMetrics;

  /// Returns the latest error message for metrics calculation, if present.
  String? get metricsError => _metricsError;

  /// Returns the last metrics calculation result, if available.
  Map<String, dynamic>? get lastMetricsResult => _lastMetricsResult;

  /// Whether the service is currently syncing user createdAt from Auth.
  bool get isSyncingCreatedAt => _syncingCreatedAt;

  /// Returns the latest error message for createdAt sync, if present.
  String? get syncCreatedAtError => _syncCreatedAtError;

  /// Returns the last createdAt sync result, if available.
  Map<String, dynamic>? get lastSyncCreatedAtResult => _lastSyncCreatedAtResult;

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
          .orderBy('createdAt', descending: true)
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
      final int spotsCreatedCount = await _countDocuments(
        _firestore.collection('spots').where('createdBy', isEqualTo: userId),
      );

      final stats = UserStats(
        spotReports: reportedCount,
        ratings: ratingsCount,
        spotsCreated: spotsCreatedCount,
      );
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

  /// Updates feature access for a user and updates internal cache.
  /// 
  /// [featureName] is the name of the feature (e.g., "spotLists").
  /// [hasAccess] indicates whether the user should have access to the feature.
  /// 
  /// This method merges the new feature access with existing feature access,
  /// so other features are not affected.
  Future<bool> updateFeatureAccess(String userId, String featureName, bool hasAccess) async {
    if (_updatingFeatureAccessFor.contains(userId)) {
      return false;
    }

    _updatingFeatureAccessFor.add(userId);
    notifyListeners();

    try {
      // Get current user to preserve existing feature access
      final userIndex = _users.indexWhere((u) => u.id == userId);
      Map<String, bool>? currentFeatureAccess;
      
      if (userIndex != -1) {
        currentFeatureAccess = Map<String, bool>.from(_users[userIndex].featureAccess ?? {});
      } else {
        // If user not in cache, fetch from Firestore
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['featureAccess'] != null) {
            currentFeatureAccess = Map<String, bool>.from(data['featureAccess']);
          }
        }
        currentFeatureAccess ??= <String, bool>{};
      }

      // Update the specific feature access
      currentFeatureAccess[featureName] = hasAccess;

      // Update in Firestore
      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        'featureAccess': currentFeatureAccess,
      });

      // Update local cache
      if (userIndex != -1) {
        _users[userIndex] = _users[userIndex].copyWith(featureAccess: currentFeatureAccess);
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('UserManagementService.updateFeatureAccess error: $e');
      debugPrint('$stackTrace');
      return false;
    } finally {
      _updatingFeatureAccessFor.remove(userId);
      notifyListeners();
    }
  }

  /// Triggers the calculation of user activity metrics (DAU/WAU/MAU)
  /// and syncs them to Google Sheets.
  Future<Map<String, dynamic>?> calculateUserActivityMetrics() async {
    if (_calculatingMetrics) {
      return _lastMetricsResult;
    }

    _calculatingMetrics = true;
    _metricsError = null;
    notifyListeners();

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'testCalculateUserActivityMetrics',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>?;

      _lastMetricsResult = data;
      return data;
    } catch (e, stackTrace) {
      _metricsError = 'Failed to calculate metrics: $e';
      debugPrint('UserManagementService.calculateUserActivityMetrics error: $e');
      debugPrint('$stackTrace');
      return null;
    } finally {
      _calculatingMetrics = false;
      notifyListeners();
    }
  }

  /// Syncs user.createdAt from Firebase Auth creation time.
  /// 
  /// [dryRun] if true, previews changes without updating.
  /// [limit] optional limit on number of users to process (for testing).
  Future<Map<String, dynamic>?> syncUserCreatedAtFromAuth({
    bool dryRun = false,
    int? limit,
  }) async {
    if (_syncingCreatedAt) {
      return _lastSyncCreatedAtResult;
    }

    _syncingCreatedAt = true;
    _syncCreatedAtError = null;
    notifyListeners();

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'syncUserCreatedAtFromAuth',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );

      final result = await callable.call({
        'dryRun': dryRun,
        if (limit != null) 'limit': limit,
      });
      final data = result.data as Map<String, dynamic>?;

      _lastSyncCreatedAtResult = data;
      
      // Refresh users list if sync was successful and not a dry run
      if (data?['success'] == true && !dryRun) {
        await fetchUsers(forceRefresh: true);
      }
      
      return data;
    } catch (e, stackTrace) {
      _syncCreatedAtError = 'Failed to sync user createdAt: $e';
      debugPrint('UserManagementService.syncUserCreatedAtFromAuth error: $e');
      debugPrint('$stackTrace');
      return null;
    } finally {
      _syncingCreatedAt = false;
      notifyListeners();
    }
  }

  Future<int> _countDocuments(Query<Map<String, dynamic>> query) async {
    try {
      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
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
