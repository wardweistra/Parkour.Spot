import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart' as app_user;
import '../models/user_contribution_stats.dart';

class UserProfileService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection with the public fields of every user; `users/{uid}` itself is
  /// only readable by its owner and admins (see firestore.rules).
  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  /// Get user profile by ID or username
  /// Returns null if user not found or profile is private (unless currentUserId matches)
  /// Other users' profiles come from `publicProfiles`, so they never include
  /// email or other private fields; your own profile is read in full.
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

      DocumentSnapshot<Map<String, dynamic>>? doc;

      // Try to fetch by user ID first (if it looks like a Firebase UID)
      // Firebase UIDs are typically 28 characters
      if (userIdOrUsername.length == 28) {
        doc = await _publicProfiles.doc(userIdOrUsername).get();
      }

      // If not found by ID, try username lookup (case-insensitive)
      if (doc == null || !doc.exists) {
        final querySnapshot = await _publicProfiles
            .where('username', isEqualTo: userIdOrUsername.toLowerCase())
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          doc = querySnapshot.docs.first;
        }
      }

      final isOwnLookup =
          currentUserId != null && userIdOrUsername == currentUserId;
      final resolvedUserId = (doc != null && doc.exists)
          ? doc.id
          : (isOwnLookup ? currentUserId : null);
      if (resolvedUserId == null) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return null;
      }

      final isOwnProfile = resolvedUserId == currentUserId;
      Map<String, dynamic>? data;
      if (isOwnProfile) {
        // Own profile: the full private document.
        data = (await _firestore.collection('users').doc(resolvedUserId).get())
            .data();
      } else if (doc!.data()?['isPublicProfile'] != false) {
        data = doc.data();
      }

      if (data == null) {
        _isLoading = false;
        Future.microtask(() => notifyListeners());
        return null; // Missing, or private and not own profile
      }

      final user = app_user.User.fromMap({
        ...data,
        'id': resolvedUserId,
        'email': isOwnProfile ? (data['email'] ?? '') : '',
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

      final querySnapshot = await _publicProfiles
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
        _error = 'Username must be 27 characters or less to avoid conflicts with user IDs';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (!RegExp(r'^[a-zA-Z0-9_-]{3,27}$').hasMatch(trimmedUsername)) {
        _error = 'Username must be 3-27 characters and contain only letters, numbers, underscores, and hyphens';
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

  /// All-time contribution totals from `userStats/{uid}`.
  ///
  /// A user without contributions has no document, which reads as
  /// [UserContributionStats.empty]. Returns null when the read fails (e.g. the
  /// profile became private), so callers can hide the section.
  Future<UserContributionStats?> getContributionStats(String userId) async {
    try {
      final doc = await _firestore.collection('userStats').doc(userId).get();
      return UserContributionStats.allTimeFromDocument(doc.data());
    } catch (e) {
      debugPrint('Error getting contribution stats: $e');
      return null;
    }
  }
}
