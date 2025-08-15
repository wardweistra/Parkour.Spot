import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isLoading => _isLoading;
  
  bool _isLoading = false;
  app_user.User? _userProfile;

  app_user.User? get userProfile => _userProfile;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _loadUserProfile(user.uid);
    } else {
      _userProfile = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userProfile = app_user.User.fromMap({
          'id': uid,
          ...doc.data() as Map<String, dynamic>,
        });
      } else {
        // Create user profile if it doesn't exist
        _userProfile = app_user.User(
          id: uid,
          email: _auth.currentUser?.email ?? '',
          displayName: _auth.currentUser?.displayName,
          photoURL: _auth.currentUser?.photoURL,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(uid).set(_userProfile!.toMap());
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (_auth.currentUser != null) {
        await _updateLastLogin();
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

  Future<bool> createUserWithEmailAndPassword(
    String email, 
    String password, 
    String displayName
  ) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        
        // Create user profile in Firestore
        final user = app_user.User(
          id: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(user.id).set(user.toMap());
        _userProfile = user;
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

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<void> _updateLastLogin() async {
    if (_auth.currentUser != null) {
      try {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'lastLoginAt': DateTime.now(),
        });
      } catch (e) {
        debugPrint('Error updating last login: $e');
      }
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    if (_auth.currentUser != null && _userProfile != null) {
      try {
        final updates = <String, dynamic>{};
        if (displayName != null) updates['displayName'] = displayName;
        if (photoURL != null) updates['photoURL'] = photoURL;
        
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(updates);
        
        _userProfile = _userProfile!.copyWith(
          displayName: displayName ?? _userProfile!.displayName,
          photoURL: photoURL ?? _userProfile!.photoURL,
        );
        
        notifyListeners();
      } catch (e) {
        debugPrint('Error updating profile: $e');
      }
    }
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
