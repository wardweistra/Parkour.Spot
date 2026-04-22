import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/admin_push_subscription_summary.dart';

/// Admin-only: load a user's FCM web push subscription docs and send test pushes.
class AdminPushSubscriptionsService extends ChangeNotifier {
  AdminPushSubscriptionsService();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  String? _targetUid;
  List<AdminPushSubscriptionSummary> _subscriptions =
      const <AdminPushSubscriptionSummary>[];
  bool _isLoadingList = false;
  bool _isSending = false;
  String? _error;
  String? _lastSendSummary;

  String? get targetUid => _targetUid;

  List<AdminPushSubscriptionSummary> get subscriptions =>
      List<AdminPushSubscriptionSummary>.unmodifiable(_subscriptions);

  bool get isLoadingList => _isLoadingList;

  bool get isSending => _isSending;

  String? get error => _error;

  String? get lastSendSummary => _lastSendSummary;

  /// Clears selection state for a new target user.
  void setTargetUid(String? uid) {
    final trimmed = uid?.trim();
    _targetUid = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _subscriptions = const <AdminPushSubscriptionSummary>[];
    _error = null;
    _lastSendSummary = null;
    notifyListeners();
  }

  Future<void> fetchSubscriptionsForTarget(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      _error = 'User id is required';
      notifyListeners();
      return;
    }

    _isLoadingList = true;
    _error = null;
    _lastSendSummary = null;
    _targetUid = trimmed;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable(
        'listPushSubscriptionsForAdmin',
      );
      final result = await callable.call(<String, dynamic>{
        'targetUid': trimmed,
      });
      final raw = result.data;
      if (raw is! Map) {
        throw StateError(
          'listPushSubscriptionsForAdmin: expected map response',
        );
      }
      final map = Map<String, dynamic>.from(raw);
      final list = map['subscriptions'];
      if (list is! List) {
        throw StateError(
          'listPushSubscriptionsForAdmin: missing subscriptions',
        );
      }
      _subscriptions = list
          .whereType<Map>()
          .map(
            (e) => AdminPushSubscriptionSummary.fromCallableMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false);
    } catch (e, st) {
      debugPrint(
        'AdminPushSubscriptionsService.fetchSubscriptionsForTarget: $e\n$st',
      );
      _error = e.toString();
      _subscriptions = const <AdminPushSubscriptionSummary>[];
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  /// Sends one FCM notification per selected subscription (same title/body).
  Future<bool> sendToSubscriptions({
    required List<String> subscriptionIds,
    required String title,
    required String body,
  }) async {
    final uid = _targetUid;
    if (uid == null || uid.isEmpty) {
      _error = 'No user selected';
      notifyListeners();
      return false;
    }
    if (subscriptionIds.isEmpty) {
      _error = 'Select at least one subscription';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _error = null;
    _lastSendSummary = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable(
        'sendWebPushToUserSubscriptions',
      );
      final payload = <String, dynamic>{
        'targetUid': uid,
        'subscriptionIds': subscriptionIds,
        'title': title,
        'body': body,
        if (kIsWeb) 'webAppBaseUrl': web.window.location.origin,
      };
      final result = await callable.call(payload);
      final raw = result.data;
      if (raw is! Map) {
        throw StateError(
          'sendWebPushToUserSubscriptions: expected map response',
        );
      }
      final map = Map<String, dynamic>.from(raw);
      final successCount = (map['successCount'] as num?)?.toInt() ?? 0;
      final failureCount = (map['failureCount'] as num?)?.toInt() ?? 0;
      final skipped = map['skipped'];
      final failures = map['failures'];
      final clickLink = map['clickLink'] as String?;
      final skippedN = skipped is List ? skipped.length : 0;
      String? firstErr;
      if (failures is List && failures.isNotEmpty) {
        final f0 = failures.first;
        if (f0 is Map) {
          firstErr = f0['error']?.toString();
        }
      }
      _lastSendSummary =
          'Sent: $successCount, failed: $failureCount, skipped: $skippedN'
          '${clickLink != null ? '\nClick link: $clickLink' : ''}'
          '${firstErr != null ? '\nFirst error: $firstErr' : ''}';
      return failureCount == 0 && successCount > 0;
    } catch (e, st) {
      debugPrint('AdminPushSubscriptionsService.sendToSubscriptions: $e\n$st');
      _error = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
