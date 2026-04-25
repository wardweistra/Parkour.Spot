import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;

class UserProfileService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get user profile by ID or username
  /// Returns null if user not found or profile is private (unless currentUserId matches)
  /// Note: Email is excluded from public profiles unless viewing own profile
  /// [currentUserId] - Optional current user ID to allow viewing own private profile
  Future<app_user.User?> getUserProfile(
    String userIdOrUsername, {
    String? currentUserId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      // Defer notifyListeners to avoid calling during build phase
      Future.microtask(() => notifyListeners());

      DocumentSnapshot? doc;
      String? resolvedUserId;

      // Try to fetch by user ID first (if it looks like a Firebase UID)
      // Firebase UIDs are typically 28 characters
      if (userIdOrUsername.length == 28) {
        doc = await _firestore.collection('users').doc(userIdOrUsername).get();
        if (doc.exists) {
          resolvedUserId = doc.id;
        }
      }

      // If not found by ID, try username lookup (case-insensitive)
      if (doc == null || !doc.exists) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: userIdOrUsername.toLowerCase())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          doc = querySnapshot.docs.first;
          resolvedUserId = doc.id;
        }
      }

      if (doc == null || !doc.exists) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Check if profile is public
      final isPublicProfile = data['isPublicProfile'] ?? true;
      final isOwnProfile =
          currentUserId != null && resolvedUserId == currentUserId;

      // Allow viewing own profile even if private
      if (!isPublicProfile && !isOwnProfile) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return null; // Profile is private and not own profile
      }

      // Create user object
      // Exclude email for public profiles, include for own profile
      final user = app_user.User.fromMap({
        'id': doc.id,
        ...data,
        'email': isOwnProfile
            ? (data['email'] ?? '')
            : '', // Include email only for own profile
      });

      _isLoading = false;
      Future.microtask(() => notifyListeners());
      return user;
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
      debugPrint('Error fetching user profile: $e');
      _isLoading = false;
      Future.microtask(() => notifyListeners());
      return null;
    }
  }

  /// Check if a username is available
  /// Returns true if username is available, false if already taken
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      if (username.trim().isEmpty) {
        return false;
      }

      // Validate username format (alphanumeric, underscore, hyphen, 3-27 chars)
      // Max length is 27 to prevent conflicts with 28-character user IDs
      final trimmedUsername = username.trim();
      if (trimmedUsername.length >= 28) {
        return false;
      }
      if (!RegExp(r'^[a-zA-Z0-9_-]{3,27}$').hasMatch(trimmedUsername)) {
        return false;
      }

      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: trimmedUsername.toLowerCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  /// Update username for a user
  /// Returns true on success, false on failure
  Future<bool> updateUsername(String userId, String username) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Validate username format
      final trimmedUsername = username.trim();
      if (trimmedUsername.isEmpty) {
        _error = 'Username cannot be empty';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate username length (max 27 to prevent conflicts with 28-character user IDs)
      if (trimmedUsername.length >= 28) {
        _error =
            'Username must be 27 characters or less to avoid conflicts with user IDs';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (!RegExp(r'^[a-zA-Z0-9_-]{3,27}$').hasMatch(trimmedUsername)) {
        _error =
            'Username must be 3-27 characters and contain only letters, numbers, underscores, and hyphens';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final normalizedUsername = trimmedUsername.toLowerCase();

      // Check if username is available
      final isAvailable = await checkUsernameAvailability(normalizedUsername);
      if (!isAvailable) {
        // Check if it's the current user's username
        final currentUserDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();
        if (currentUserDoc.exists) {
          final currentData = currentUserDoc.data() as Map<String, dynamic>;
          final currentUsername = currentData['username'] as String?;
          if (currentUsername?.toLowerCase() == normalizedUsername) {
            // Same username, no change needed
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }

        _error = 'Username is already taken';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update username
      await _firestore.collection('users').doc(userId).update({
        'username': normalizedUsername,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update username: $e';
      debugPrint('Error updating username: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update profile privacy setting
  /// Returns true on success, false on failure
  Future<bool> updateProfilePrivacy(String userId, bool isPublic) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(userId).update({
        'isPublicProfile': isPublic,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile privacy: $e';
      debugPrint('Error updating profile privacy: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get user statistics (spots created, ratings given)
  /// Returns a map with 'spotsCreated' and 'ratings' counts
  Future<Map<String, int>?> getUserStats(String userId) async {
    try {
      final int totalSpotsCreatedCount = await _countDocuments(
        _firestore.collection('spots').where('createdBy', isEqualTo: userId),
      );
      final int createNativeSpotsCount = await _countDocuments(
        _firestore
            .collection('spots')
            .where('createdBy', isEqualTo: userId)
            .where('createdFromCreateNative', isEqualTo: true),
      );
      final int spotsCreatedCount =
          (totalSpotsCreatedCount - createNativeSpotsCount).clamp(0, 1 << 30);
      final int ratingsCount = await _countDocuments(
        _firestore.collection('ratings').where('userId', isEqualTo: userId),
      );

      return {'spotsCreated': spotsCreatedCount, 'ratings': ratingsCount};
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return null;
    }
  }

  /// Helper method to count documents with fallback for missing indexes
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
