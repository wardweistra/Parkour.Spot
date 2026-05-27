import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_notification.dart';
import 'auth_service.dart';

class UserNotificationService extends ChangeNotifier {
  UserNotificationService(this._authService);

  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _error;

  String? get error => _error;

  /// Shared Firestore listener for all UI subscribers (explore nav + profile tab).
  Stream<List<UserNotification>>? _notificationsStream;
  String? _notificationsStreamUid;

  String? get _uid => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _notificationsCollection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<UserNotification>> watchNotifications() {
    final uid = _uid;
    final collection = _notificationsCollection;
    if (collection == null) {
      _notificationsStream = null;
      _notificationsStreamUid = null;
      return Stream<List<UserNotification>>.value(const []);
    }
    if (_notificationsStream != null && _notificationsStreamUid == uid) {
      return _notificationsStream!;
    }
    _notificationsStreamUid = uid;
    _notificationsStream = collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UserNotification.fromFirestore)
              .toList(growable: false),
        );
    return _notificationsStream!;
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((n) => !n.read).length,
    );
  }

  Future<bool> markAsRead(String notificationId) async {
    final uid = _uid;
    final collection = _notificationsCollection;
    if (uid == null || collection == null) {
      return false;
    }
    _error = null;
    try {
      await collection.doc(notificationId).update({'read': true});
      return true;
    } catch (e, st) {
      debugPrint('UserNotificationService.markAsRead: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsUnread(String notificationId) async {
    final uid = _uid;
    final collection = _notificationsCollection;
    if (uid == null || collection == null) {
      return false;
    }
    _error = null;
    try {
      await collection.doc(notificationId).update({'read': false});
      return true;
    } catch (e, st) {
      debugPrint('UserNotificationService.markAsUnread: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Marks every notification in the inbox as read (batched; handles >500 docs).
  Future<bool> markAllAsRead() async {
    final collection = _notificationsCollection;
    if (collection == null) {
      return false;
    }
    _error = null;
    try {
      final snapshot = await collection.where('read', isEqualTo: false).get();
      if (snapshot.docs.isEmpty) {
        return true;
      }
      const chunk = 500;
      for (var i = 0; i < snapshot.docs.length; i += chunk) {
        final batch = _firestore.batch();
        final end = (i + chunk > snapshot.docs.length)
            ? snapshot.docs.length
            : i + chunk;
        for (var j = i; j < end; j++) {
          batch.update(snapshot.docs[j].reference, {'read': true});
        }
        await batch.commit();
      }
      return true;
    } catch (e, st) {
      debugPrint('UserNotificationService.markAllAsRead: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
