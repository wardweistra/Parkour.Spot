import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_notification.dart';

/// One in-app notification plus the recipient user id (Firestore path
/// `users/{uid}/notifications/{id}`).
class AdminNotificationEntry {
  const AdminNotificationEntry({
    required this.recipientUserId,
    required this.notification,
    required this.documentReference,
  });

  final String recipientUserId;
  final UserNotification notification;
  final DocumentReference<Map<String, dynamic>> documentReference;
}

/// Paginated collection-group query over all users' notification inboxes (admin only).
class AdminNotificationsService extends ChangeNotifier {
  AdminNotificationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final List<AdminNotificationEntry> _entries = <AdminNotificationEntry>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;

  static const int _defaultPageSize = 50;

  List<AdminNotificationEntry> get entries =>
      List<AdminNotificationEntry>.unmodifiable(_entries);

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  String? get error => _error;

  /// Loads the first page (newest [createdAt] first).
  Future<void> fetchInitial({bool forceRefresh = false, int pageSize = _defaultPageSize}) async {
    if (_isLoading && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    if (forceRefresh) {
      _entries.clear();
      _lastDocument = null;
      _hasMore = true;
    }
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collectionGroup('notifications')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();

      _applyPage(snapshot, pageSize, replaceExisting: true);
    } catch (e, stackTrace) {
      _error = 'Failed to load notifications';
      debugPrint('AdminNotificationsService.fetchInitial error: $e');
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page using the Firestore cursor.
  Future<void> loadMore({int pageSize = _defaultPageSize}) async {
    if (!_hasMore || _isLoading || _isLoadingMore || _lastDocument == null) {
      return;
    }

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collectionGroup('notifications')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(pageSize)
          .get();

      _applyPage(snapshot, pageSize, replaceExisting: false);
    } catch (e, stackTrace) {
      _error = 'Failed to load more notifications';
      debugPrint('AdminNotificationsService.loadMore error: $e');
      debugPrint('$stackTrace');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _applyPage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int pageSize, {
    required bool replaceExisting,
  }) {
    final docs = snapshot.docs;
    if (replaceExisting) {
      _entries.clear();
    }

    for (final doc in docs) {
      final userRef = doc.reference.parent.parent;
      final recipientUserId = userRef?.id ?? '';
      _entries.add(
        AdminNotificationEntry(
          recipientUserId: recipientUserId,
          notification: UserNotification.fromFirestore(doc),
          documentReference: doc.reference,
        ),
      );
    }

    if (replaceExisting) {
      _lastDocument = docs.isNotEmpty ? docs.last : null;
      _hasMore = docs.length >= pageSize;
    } else if (docs.isEmpty) {
      _hasMore = false;
    } else {
      _lastDocument = docs.last;
      _hasMore = docs.length >= pageSize;
    }
  }

  /// Deletes a notification document. Returns true on success.
  Future<bool> deleteNotification(AdminNotificationEntry entry) async {
    _error = null;
    try {
      await entry.documentReference.delete();
      _entries.removeWhere((e) => e.documentReference.path == entry.documentReference.path);
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('AdminNotificationsService.deleteNotification: $e\n$st');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
