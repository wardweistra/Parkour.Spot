import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart' as app_user;
import 'profile_picture_service.dart';
import 'snackbar_service.dart';
import 'user_profile_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  final UserProfileService _userProfileService = UserProfileService();

  User? get currentUser => _auth.currentUser;
  bool get isAdmin => _userProfile?.isAdmin == true;
  bool get isModerator => _userProfile?.isModerator == true;
  bool get isAuthenticated {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Require email verification for password (email/password) accounts
    final hasPasswordProvider = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    if (hasPasswordProvider) {
      return user.emailVerified;
    }
    // For other providers (e.g., Google, Apple), consider authenticated
    return true;
  }

  bool get isLoading => _isLoading;

  /// True when authenticated and user profile has loaded from Firestore.
  /// Use this to gate authenticated actions (add spot, rate, report) so we
  /// have displayName, isAdmin, etc. available instead of falling back to email.
  bool get isProfileReady => isAuthenticated && _userProfile != null;

  /// Error message when profile load failed (e.g. guard against overwrite).
  /// Cleared on sign out or successful load.
  String? get profileLoadError => _profileLoadError;
  String? _profileLoadError;

  /// Retry loading the profile after a guard failure. Clears the error and
  /// triggers a fresh load. Use when user taps "Retry" or "Refresh".
  Future<void> retryProfileLoad() async {
    _profileLoadError = null;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      notifyListeners();
      await _loadUserProfile(uid);
    }
  }

  bool _isLoading = true; // Start as loading while auth state is being restored
  app_user.User? _userProfile;
  bool _isCopyingGooglePicture =
      false; // Track if Google picture copy is in progress
  bool _isLoadingProfile = false; // Prevent concurrent profile loads
  String? _loadingProfileUid; // Track which UID is currently being loaded
  final Map<String, Completer<void>> _profileLoadCompleters =
      {}; // Track profile load completers by UID

  app_user.User? get userProfile => _userProfile;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _isLoading =
          true; // Stay loading until profile is fetched (fixes refresh on admin routes)
      _loadUserProfile(user.uid);
    } else {
      _userProfile = null;
      _profileLoadError = null;
      _isLoadingProfile = false; // Reset flag on logout
      _loadingProfileUid = null; // Reset UID tracking on logout
      _isLoading = false; // Auth state restored, no user
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String uid) async {
    // Prevent concurrent or duplicate profile loads for the same UID
    // Set flags synchronously BEFORE any async operations to prevent race conditions
    if (_isLoadingProfile) {
      if (_loadingProfileUid == uid) {
        // Profile is already being loaded for this UID, wait for it to complete
        final completer = _profileLoadCompleters[uid];
        if (completer != null) {
          return completer.future;
        }
      } else {
        return;
      }
    }

    // Create a completer to track this profile load
    final completer = Completer<void>();
    _profileLoadCompleters[uid] = completer;

    // Set flags immediately (synchronously) to prevent race conditions
    _isLoadingProfile = true;
    _loadingProfileUid = uid;
    try {
      // Ensure auth token is ready before Firestore read (fixes "permission denied" on page refresh)
      final user = _auth.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }
      // Use Source.server to avoid cache fallback race: when server is unreachable,
      // Firestore falls back to cache; empty cache yields doc.exists=false and we'd
      // incorrectly overwrite existing users with new createdAt/isAdmin=false.
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (doc.exists) {
        _profileLoadError = null;
        final data = doc.data() as Map<String, dynamic>;
        _userProfile = app_user.User.fromMap({'id': uid, ...data});
      } else {
        // Guard against overwrite: if Auth user was created long ago, Firestore
        // get() may have returned stale "no doc" (e.g. cache bug). Retry before
        // creating, and refuse to overwrite if we still get no doc.
        final authUser = _auth.currentUser;
        final authCreatedAt = authUser?.metadata.creationTime;
        const guardThreshold = Duration(minutes: 5);

        if (authCreatedAt != null &&
            DateTime.now().difference(authCreatedAt) > guardThreshold) {
          // Auth user is old — doc likely exists; retry get to avoid cache bug
          for (var i = 0; i < 2; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            final retryDoc = await _firestore
                .collection('users')
                .doc(uid)
                .get(const GetOptions(source: Source.server));
            if (retryDoc.exists) {
              _profileLoadError = null;
              final data = retryDoc.data() as Map<String, dynamic>;
              _userProfile = app_user.User.fromMap({'id': uid, ...data});
              completer.complete();
              return;
            }
          }
          // Still no doc after retries — refuse to overwrite; user should refresh
          const message =
              'Profile not found for existing account. Please refresh the page.';
          _profileLoadError = message;
          SnackbarService.showError(message);
          completer.completeError(StateError(message));
          return;
        }

        // Create user profile if it doesn't exist (Auth user is new)
        _profileLoadError = null;
        _userProfile = app_user.User(
          id: uid,
          email: _auth.currentUser?.email ?? '',
          displayName: _auth.currentUser?.displayName,
          photoURL: _auth.currentUser?.photoURL,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isAdmin: false,
          isModerator: false,
          featureAccess: null,
        );
        await _firestore
            .collection('users')
            .doc(uid)
            .set(_userProfile!.toMap());
      }

      // Note: lastActiveAt is updated by the router observer on page views/navigation
      // We don't update it here to avoid duplicate updates on initial page load
      // The router observer's retry mechanism handles the initial page load case

      // Note: Google profile picture copy is handled in sign-in methods, not here
      // This prevents copying on every page refresh

      // Complete the completer to signal that profile loading is done
      completer.complete();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      completer.completeError(e);
    } finally {
      _isLoadingProfile = false;
      _loadingProfileUid = null;
      _isLoading = false; // Auth state restored
      _profileLoadCompleters.remove(uid);
      notifyListeners();
    }
  }

  /// Wait for the user profile to be loaded for the current user
  /// Returns true if profile is loaded, false if user is not authenticated
  Future<bool> _ensureProfileLoaded() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    final uid = currentUser.uid;

    // If profile is already loaded for this UID, return immediately
    if (_userProfile != null && _userProfile!.id == uid && !_isLoadingProfile) {
      return true;
    }

    // If profile is currently being loaded, wait for it
    if (_isLoadingProfile && _loadingProfileUid == uid) {
      final completer = _profileLoadCompleters[uid];
      if (completer != null) {
        try {
          await completer.future;
          return _userProfile != null && _userProfile!.id == uid;
        } catch (e) {
          debugPrint('Error waiting for profile load: $e');
          return false;
        }
      }
    }

    // If profile is not loaded and not loading, trigger load and wait
    if (!_isLoadingProfile || _loadingProfileUid != uid) {
      try {
        await _loadUserProfile(uid);
        return _userProfile != null && _userProfile!.id == uid;
      } catch (e) {
        debugPrint('Error loading profile: $e');
        return false;
      }
    }

    return false;
  }

  /// Copy Google profile picture to Firebase Storage if:
  /// 1. User has a Google photoURL
  /// 2. User doesn't already have a Firebase Storage profile picture
  /// 3. Copy is not already in progress
  /// This runs asynchronously and doesn't block the login flow
  void _copyGoogleProfilePictureIfNeeded() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _userProfile == null) return;

    // Don't copy if already in progress
    if (_isCopyingGooglePicture) {
      debugPrint('Google picture copy already in progress, skipping');
      return;
    }

    final googlePhotoURL = currentUser.photoURL;
    final storedPhotoURL = _userProfile!.photoURL;

    // Check if user has a Google profile picture
    if (googlePhotoURL == null || googlePhotoURL.isEmpty) {
      return;
    }

    // Check if user already has a Firebase Storage profile picture
    if (_profilePictureService.isFirebaseStorageProfilePictureUrl(
      storedPhotoURL,
    )) {
      debugPrint(
        'User already has Firebase Storage profile picture, skipping copy',
      );
      return;
    }

    // Only copy if stored photoURL is also a Google URL (not already copied)
    // This prevents re-copying if the profile still has Google URL but copy is in progress
    if (!_profilePictureService.isGoogleProfilePictureUrl(storedPhotoURL)) {
      debugPrint('Stored photoURL is not a Google URL, skipping copy');
      return;
    }

    // Copy Google picture to Storage asynchronously (don't block)
    _copyGooglePictureToStorage(googlePhotoURL);
  }

  /// Copy Google profile picture to Storage (async helper)
  Future<void> _copyGooglePictureToStorage(String googlePhotoURL) async {
    // Set flag to prevent duplicate copies
    if (_isCopyingGooglePicture) {
      debugPrint('Copy already in progress, skipping');
      return;
    }

    _isCopyingGooglePicture = true;

    try {
      // Check if file already exists in Storage before copying
      final user = _auth.currentUser;
      if (user != null) {
        final fileName = 'users/${user.uid}/profile.jpg';
        final ref = _storage.ref().child(fileName);

        try {
          // Try to get metadata - if it exists, we already have the picture
          await ref.getMetadata();
          debugPrint(
            'Profile picture already exists in Storage, skipping copy',
          );

          // Get the download URL and update profile if it's not already set
          final existingURL = await ref.getDownloadURL();
          final storedPhotoURL = _userProfile?.photoURL;

          if (storedPhotoURL != existingURL) {
            debugPrint('Updating profile with existing Storage URL');
            await updateProfile(photoURL: existingURL, deleteOldPhoto: false);
          }

          return;
        } catch (e) {
          // File doesn't exist, proceed with copy
          debugPrint(
            'Profile picture not found in Storage, proceeding with copy',
          );
        }
      }

      debugPrint('Copying Google profile picture to Storage');
      final storageURL = await _profilePictureService.copyImageFromUrl(
        googlePhotoURL,
      );
      // Update profile with Storage URL
      await updateProfile(photoURL: storageURL, deleteOldPhoto: false);
      debugPrint('Successfully copied Google profile picture to Storage');
    } catch (e) {
      debugPrint('Error copying Google profile picture to Storage: $e');
      // Non-critical error - user can still use the app with Google URL
    } finally {
      _isCopyingGooglePicture = false;
    }
  }

  /// Check if the authentication state has been fully restored
  bool get isAuthStateRestored => !_isLoading;

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Reload user to ensure latest emailVerified state
      await _auth.currentUser?.reload();

      if (_auth.currentUser != null) {
        await _updateLastLogin();
        // Check if user signed in with Google (might have linked accounts)
        // and copy Google profile picture if needed
        _copyGoogleProfilePictureIfNeeded();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    if (!kIsWeb) {
      debugPrint('Google Sign-In is only supported on web');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Create a new provider
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithPopup(googleProvider);

      if (userCredential.user != null) {
        await _updateLastLogin();
        // Copy Google profile picture to Storage on login (not on page refresh)
        _copyGoogleProfilePictureIfNeeded();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        // Send email verification to the newly created user
        try {
          await userCredential.user!.sendEmailVerification();
        } catch (e) {
          debugPrint('Failed to send verification email: $e');
        }

        // Create user profile in Firestore
        final user = app_user.User(
          id: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isAdmin: false,
          featureAccess: null,
        );

        await _firestore.collection('users').doc(user.id).set(user.toMap());
        _userProfile = user;

        // Note: Email/password accounts don't have Google profile pictures
        // so no need to copy profile picture here
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign up error: ${e.message}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      debugPrint('Error sending email verification: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<void> _updateLastLogin() async {
    if (_auth.currentUser == null) {
      return;
    }

    // CRITICAL: Wait for profile to be loaded before updating lastLoginAt
    // This prevents race conditions where createdAt might be overwritten
    final profileLoaded = await _ensureProfileLoaded();
    if (!profileLoaded) {
      debugPrint('Warning: Could not load profile before updating last login');
      return;
    }

    try {
      final now = DateTime.now();
      final uid = _auth.currentUser!.uid;

      // Use update() to only modify lastLoginAt and lastActiveAt
      // This ensures createdAt is never overwritten
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': now,
        'lastActiveAt': now, // Also update lastActiveAt on login
      });

      // Update local profile if it exists
      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(
          lastLoginAt: now,
          lastActiveAt: now,
        );
      }
    } catch (e) {
      debugPrint('Error updating last login: $e');
      // If update fails because document doesn't exist, that's okay
      // The profile loader will create it on next load
    }
  }

  /// Update lastActiveAt timestamp for the current user
  /// This is called on every page view for logged-in users
  Future<void> updateLastActiveAt() async {
    if (_auth.currentUser == null) {
      return;
    }

    try {
      final now = DateTime.now();
      final uid = _auth.currentUser!.uid;

      // Use update() to only modify lastActiveAt
      // This ensures createdAt and other fields are never overwritten
      await _firestore.collection('users').doc(uid).update({
        'lastActiveAt': now,
      });

      // Update local profile if it exists
      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(lastActiveAt: now);
      }
    } catch (e) {
      debugPrint('Error updating last active: $e');
      // If update fails because document doesn't exist, that's okay
      // The profile loader will create it on next load
    }
  }

  /// Update user profile with optional display name and photo URL
  /// Returns true on success, false on failure
  /// If removePhoto is true, photoURL will be set to null (removing the profile picture)
  /// If removeDisplayName is true, displayName will be set to null
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
    String? instagramUrl,
    bool deleteOldPhoto = false,
    bool removePhoto = false,
    bool removeDisplayName = false,
    bool removeInstagramUrl = false,
  }) async {
    if (_auth.currentUser == null || _userProfile == null) {
      debugPrint(
        'Cannot update profile: user not authenticated or profile not loaded',
      );
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final oldPhotoURL = _userProfile!.photoURL;
      final updates = <String, dynamic>{};

      if (removeDisplayName) {
        updates['displayName'] = null;
      } else if (displayName != null) {
        updates['displayName'] = displayName;
      }

      // Handle photoURL update
      if (removePhoto) {
        // Explicitly removing profile picture
        updates['photoURL'] = null;
      } else if (photoURL != null) {
        // Setting new photo URL
        updates['photoURL'] = photoURL;
      }

      if (removeInstagramUrl) {
        updates['instagramUrl'] = null;
      } else if (instagramUrl != null) {
        updates['instagramUrl'] = instagramUrl;
      }

      // Delete old profile picture from Storage if requested and it exists
      if (deleteOldPhoto && oldPhotoURL != null && oldPhotoURL.isNotEmpty) {
        try {
          // Check if it's a Firebase Storage URL
          if (oldPhotoURL.contains('users/$userId/')) {
            final fileName = 'users/$userId/profile.jpg';
            final ref = _storage.ref().child(fileName);
            await ref.delete();
            debugPrint('Deleted old profile picture from Storage');
          }
        } catch (e) {
          // Non-critical error - log but continue
          debugPrint('Error deleting old profile picture: $e');
        }
      }

      // Update Firestore
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }

      // Sync Firebase Auth displayName so it stays consistent
      if (removeDisplayName || displayName != null) {
        await _auth.currentUser!.updateDisplayName(
          removeDisplayName ? '' : displayName!,
        );
      }

      // Update local profile
      _userProfile = _userProfile!.copyWith(
        displayName: removeDisplayName
            ? null
            : (displayName ?? _userProfile!.displayName),
        photoURL: removePhoto ? null : (photoURL ?? _userProfile!.photoURL),
        instagramUrl: removeInstagramUrl
            ? null
            : (instagramUrl ?? _userProfile!.instagramUrl),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Update username for the current user
  /// Returns true on success, false on failure
  Future<bool> updateUsername(String username) async {
    if (_auth.currentUser == null || _userProfile == null) {
      debugPrint(
        'Cannot update username: user not authenticated or profile not loaded',
      );
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final success = await _userProfileService.updateUsername(
        userId,
        username,
      );

      if (success) {
        // Update local profile
        _userProfile = _userProfile!.copyWith(
          username: username.trim().toLowerCase(),
        );
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error updating username: $e');
      return false;
    }
  }

  /// Update profile privacy setting for the current user
  /// Returns true on success, false on failure
  Future<bool> updateProfilePrivacy(bool isPublic) async {
    if (_auth.currentUser == null || _userProfile == null) {
      debugPrint(
        'Cannot update profile privacy: user not authenticated or profile not loaded',
      );
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final success = await _userProfileService.updateProfilePrivacy(
        userId,
        isPublic,
      );

      if (success) {
        // Update local profile
        _userProfile = _userProfile!.copyWith(isPublicProfile: isPublic);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error updating profile privacy: $e');
      return false;
    }
  }

  /// Update whether the user allows storing last-known location for alerts.
  Future<bool> updateShareLastKnownLocationForAlerts(bool enabled) async {
    if (_auth.currentUser == null || _userProfile == null) {
      debugPrint(
        'Cannot update location sharing preference: user not authenticated or profile not loaded',
      );
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'shareLastKnownLocationForAlerts': enabled,
      });

      _userProfile = _userProfile!.copyWith(
        shareLastKnownLocationForAlerts: enabled,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating location sharing preference: $e');
      return false;
    }
  }

  /// Opt in or out of in-app notifications when a new spot is added near an
  /// enabled location of interest.
  Future<bool> updateNotifyNewSpotsNearby(bool enabled) async {
    if (_auth.currentUser == null || _userProfile == null) {
      debugPrint(
        'Cannot update new-spot notification preference: user not authenticated or profile not loaded',
      );
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'notifyNewSpotsNearby': enabled,
      });

      _userProfile = _userProfile!.copyWith(
        notifyNewSpotsNearby: enabled,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating new-spot notification preference: $e');
      return false;
    }
  }

  /// Update spot tracking lists in local profile (called by SpotTrackingService after Firestore update)
  void updateUserSpotTracking({
    required List<String> wantToVisit,
    required List<String> visited,
  }) {
    if (_userProfile == null) return;
    _userProfile = _userProfile!.copyWith(
      wantToVisit: wantToVisit,
      visited: visited,
    );
    notifyListeners();
  }

  /// Check if a username is available
  /// Returns true if username is available, false if already taken
  Future<bool> checkUsernameAvailability(String username) async {
    return await _userProfileService.checkUsernameAvailability(username);
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }
}
