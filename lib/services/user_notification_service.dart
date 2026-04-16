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

  String? get _uid => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _notificationsCollection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<UserNotification>> watchNotifications() {
    final collection = _notificationsCollection;
    if (collection == null) {
      return Stream<List<UserNotification>>.value(const []);
    }
    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UserNotification.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((n) => !n.read).length,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _uid;
    final collection = _notificationsCollection;
    if (uid == null || collection == null) {
      return;
    }
    _error = null;
    try {
      await collection.doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('UserNotificationService.markAsRead: $e\n$st');
      _error = e.toString();
      notifyListeners();
    }
  }
}
