import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Paginated list of all users' in-app notifications (admin only).
///
/// Uses the [listInAppNotificationsForAdmin] HTTPS callable (Admin SDK). Client-side
/// `collectionGroup('notifications')` is unreliable: that query spans every
/// subcollection named `notifications` in the project; any path without a matching
/// rule denies the entire query.
class AdminNotificationsService extends ChangeNotifier {
  AdminNotificationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  final List<AdminNotificationEntry> _entries = <AdminNotificationEntry>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _lastDiagnostics;

  /// Document path for `startAfter` on the next page (from last server response).
  String? _nextPageCursorPath;
  bool _hasMore = true;

  static const int _defaultPageSize = 50;

  List<AdminNotificationEntry> get entries =>
      List<AdminNotificationEntry>.unmodifiable(_entries);

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  String? get error => _error;

  /// Populated when a load fails.
  String? get lastDiagnostics => _lastDiagnostics;

  /// Loads the first page (newest [createdAt] first).
  Future<void> fetchInitial({bool forceRefresh = false, int pageSize = _defaultPageSize}) async {
    if (_isLoading && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    _lastDiagnostics = null;
    if (forceRefresh) {
      _entries.clear();
      _nextPageCursorPath = null;
      _hasMore = true;
    }
    notifyListeners();

    try {
      final data = await _callListInAppNotifications(
        pageSize: pageSize,
        cursorDocPath: null,
      );
      _applyCallablePage(data, replaceExisting: true);
    } catch (e, stackTrace) {
      _error = 'Failed to load notifications';
      _lastDiagnostics = await _collectAdminFirestoreDiagnostics();
      debugPrint('AdminNotificationsService.fetchInitial error: $e');
      debugPrint(_lastDiagnostics ?? '(no diagnostics)');
      debugPrint('$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page using the server cursor.
  Future<void> loadMore({int pageSize = _defaultPageSize}) async {
    if (!_hasMore || _isLoading || _isLoadingMore || _nextPageCursorPath == null) {
      return;
    }

    _isLoadingMore = true;
    _error = null;
    _lastDiagnostics = null;
    notifyListeners();

    try {
      final data = await _callListInAppNotifications(
        pageSize: pageSize,
        cursorDocPath: _nextPageCursorPath,
      );
      _applyCallablePage(data, replaceExisting: false);
    } catch (e, stackTrace) {
      _error = 'Failed to load more notifications';
      _lastDiagnostics = await _collectAdminFirestoreDiagnostics();
      debugPrint('AdminNotificationsService.loadMore error: $e');
      debugPrint(_lastDiagnostics ?? '(no diagnostics)');
      debugPrint('$stackTrace');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _callListInAppNotifications({
    required int pageSize,
    required String? cursorDocPath,
  }) async {
    final callable = _functions.httpsCallable('listInAppNotificationsForAdmin');
    final payload = <String, dynamic>{
      'pageSize': pageSize,
      if (cursorDocPath != null) 'cursor': <String, dynamic>{'docPath': cursorDocPath},
    };
    final result = await callable.call(payload);
    final raw = result.data;
    if (raw is! Map) {
      throw StateError('listInAppNotificationsForAdmin: expected map response');
    }
    return Map<String, dynamic>.from(raw);
  }

  void _applyCallablePage(
    Map<String, dynamic> data, {
    required bool replaceExisting,
  }) {
    final rawList = data['notifications'];
    if (rawList is! List) {
      throw StateError('listInAppNotificationsForAdmin: missing notifications list');
    }

    if (replaceExisting) {
      _entries.clear();
    }

    for (final item in rawList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final path = m['path'] as String?;
      if (path == null || path.isEmpty) continue;
      final recipientUserId = m['recipientUserId'] as String? ?? '';
      final payload = m['data'];
      final dataMap =
          payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
      final id = path.split('/').last;
      _entries.add(
        AdminNotificationEntry(
          recipientUserId: recipientUserId,
          notification: UserNotification.fromAdminCallable(id, dataMap),
          documentReference: _firestore.doc(path),
        ),
      );
    }

    final hasMore = data['hasMore'] == true;
    _hasMore = hasMore;
    final next = data['nextCursor'];
    if (next is Map && next['docPath'] is String) {
      _nextPageCursorPath = next['docPath'] as String;
    } else {
      _nextPageCursorPath = null;
    }

    if (!hasMore) {
      _nextPageCursorPath = null;
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

  Future<String> _collectAdminFirestoreDiagnostics() async {
    final b = StringBuffer();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      b.writeln('FirebaseAuth.currentUser: null (signed out)');
      return b.toString();
    }
    b.writeln('FirebaseAuth.currentUser.uid: ${user.uid}');
    try {
      final tr = await user.getIdTokenResult(true);
      b.writeln('claim admin: ${tr.claims?['admin']}');
    } catch (e) {
      b.writeln('getIdTokenResult(true): $e');
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      b.writeln('Firestore users/{uid}.isAdmin: ${doc.data()?['isAdmin']}');
    } catch (e) {
      b.writeln('Firestore users/{uid} get: $e');
    }
    b.writeln(
      'Listing uses HTTPS callable listInAppNotificationsForAdmin (Admin SDK). '
      'If this fails, check Functions logs / deployment. '
      'Client collectionGroup("notifications") often fails when any extra '
      'notifications subcollection exists outside users/{{uid}}.',
    );
    return b.toString();
  }
}
