import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import '../config/app_config.dart';
import 'auth_service.dart';
import 'mobile_detection_service.dart';

enum WebPushPermissionState { unknown, notDetermined, denied, authorized }

class WebPushSubscriptionService extends ChangeNotifier {
  WebPushSubscriptionService() {
    _isSupported = kIsWeb;
  }

  static const _installationIdPrefsKey = 'web_push_installation_id';
  static const _platform = 'web';
  static const _maxUserAgentLength = 600;
  static const _maxLocaleLength = 16;
  static const _logPrefix = '[WebPushSubscriptionService]';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Uuid _uuid = const Uuid();

  String? _uid;
  String? _installationId;
  bool _isBusy = false;
  bool _isSupported = false;
  bool _isSubscribed = false;
  String? _lastError;
  WebPushPermissionState _permissionState = WebPushPermissionState.unknown;

  bool get isBusy => _isBusy;
  bool get isSupported => _isSupported;
  bool get isSubscribed => _isSubscribed;
  String? get lastError => _lastError;
  WebPushPermissionState get permissionState => _permissionState;
  String? get installationId => _installationId;

  Future<void> syncAuth(AuthService authService) async {
    final uid = authService.currentUser?.uid;
    if (_uid == uid) return;
    _logInfo('syncAuth uid: ${_uid ?? 'null'} -> ${uid ?? 'null'}');
    _uid = uid;
    _lastError = null;
    if (_uid == null) {
      _isSubscribed = false;
      _permissionState = WebPushPermissionState.unknown;
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!_isSupported) return;
    await _runBusy(() async {
      _logInfo('refresh start');
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      _logInfo('refresh installationId=$_installationId');
      _permissionState = await _readPermissionState();
      _logInfo('refresh permission=${_permissionState.name}');
      if (_uid == null ||
          _permissionState != WebPushPermissionState.authorized) {
        _isSubscribed = false;
        _logWarn(
          'refresh skipped (uid=${_uid ?? 'null'}, permission=${_permissionState.name})',
        );
        return;
      }
      final token = await _getCurrentToken();
      if (token == null || token.isEmpty) {
        _isSubscribed = false;
        _logWarn('refresh no token available');
        return;
      }
      _logInfo('refresh token acquired (length=${token.length})');
      await _upsertSubscription(token: token, enabled: true);
      await _disableDuplicateTokenDocs(token: token);
      _isSubscribed = true;
      _logInfo('refresh subscription active');
    });
  }

  Future<bool> enableCurrentDevice() async {
    if (!_isSupported || _uid == null) return false;
    var success = false;
    await _runBusy(() async {
      _logInfo('enableCurrentDevice start');
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      _logInfo('enableCurrentDevice installationId=$_installationId');
      final settings = await _messaging.requestPermission();
      _permissionState = _mapPermission(settings.authorizationStatus);
      _logInfo('enableCurrentDevice permission=${_permissionState.name}');
      if (_permissionState != WebPushPermissionState.authorized) {
        _isSubscribed = false;
        _logWarn('enableCurrentDevice permission not authorized');
        return;
      }
      final token = await _getCurrentToken();
      if (token == null || token.isEmpty) {
        _isSubscribed = false;
        _lastError = 'No push token available for this browser.';
        _logWarn('enableCurrentDevice no token available');
        return;
      }
      _logInfo('enableCurrentDevice token acquired (length=${token.length})');
      await _upsertSubscription(token: token, enabled: true);
      await _disableDuplicateTokenDocs(token: token);
      _isSubscribed = true;
      success = true;
      _logInfo('enableCurrentDevice success');
    });
    return success;
  }

  Future<bool> disableCurrentDevice() async {
    if (!_isSupported || _uid == null) return false;
    var success = false;
    await _runBusy(() async {
      _logInfo('disableCurrentDevice start');
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      try {
        await _messaging.deleteToken();
        _logInfo('disableCurrentDevice deleteToken complete');
      } catch (e) {
        debugPrint('WebPushSubscriptionService.deleteToken: $e');
        _logWarn('disableCurrentDevice deleteToken failed: $e');
      }
      await _upsertSubscription(token: null, enabled: false);
      _permissionState = await _readPermissionState();
      _isSubscribed = false;
      success = true;
      _logInfo('disableCurrentDevice success');
    });
    return success;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
    } catch (e, st) {
      debugPrint('WebPushSubscriptionService: $e\n$st');
      _logError('operation failed: $e', st);
      _lastError = e.toString();
      _isSubscribed = false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> _getCurrentToken() async {
    final vapidKey = AppConfig.firebaseWebPushVapidKey.trim();
    if (vapidKey.isEmpty) {
      _lastError = 'Missing FIREBASE_WEB_PUSH_VAPID_KEY configuration.';
      _logError(_lastError!);
      return null;
    }
    try {
      _logInfo('getToken request start');
      final token = await _messaging.getToken(vapidKey: vapidKey);
      _logInfo(
        'getToken completed (hasToken=${token != null && token.isNotEmpty})',
      );
      return token;
    } catch (e) {
      _lastError = e.toString();
      _logError('getToken failed: $e');
      return null;
    }
  }

  Future<WebPushPermissionState> _readPermissionState() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return _mapPermission(settings.authorizationStatus);
    } catch (_) {
      return WebPushPermissionState.unknown;
    }
  }

  WebPushPermissionState _mapPermission(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return WebPushPermissionState.authorized;
      case AuthorizationStatus.denied:
        return WebPushPermissionState.denied;
      case AuthorizationStatus.notDetermined:
        return WebPushPermissionState.notDetermined;
    }
  }

  Future<String> _getOrCreateInstallationId() async {
    if (_installationId != null && _installationId!.isNotEmpty) {
      return _installationId!;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationIdPrefsKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      _installationId = existing;
      return existing;
    }
    final created = _uuid.v4();
    await prefs.setString(_installationIdPrefsKey, created);
    _installationId = created;
    return created;
  }

  CollectionReference<Map<String, dynamic>>? _subscriptionsCollection() {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('pushSubscriptions');
  }

  Future<void> _upsertSubscription({
    required bool enabled,
    String? token,
  }) async {
    final collection = _subscriptionsCollection();
    final installationId = _installationId;
    if (collection == null || installationId == null) return;
    _logInfo(
      'upsertSubscription doc=$installationId enabled=$enabled hasToken=${token != null && token.isNotEmpty}',
    );
    final now = FieldValue.serverTimestamp();
    final locale = ui.PlatformDispatcher.instance.locale.languageCode
        .trim()
        .toLowerCase();
    final normalizedLocale = locale.isEmpty ? null : locale;
    final userAgent = web.window.navigator.userAgent;
    await collection.doc(installationId).set({
      'installationId': installationId,
      'platform': _platform,
      'enabled': enabled,
      'token': token,
      'permission': _permissionState.name,
      'locale': normalizedLocale?.substring(
        0,
        normalizedLocale.length.clamp(0, _maxLocaleLength),
      ),
      'userAgent': userAgent.substring(
        0,
        userAgent.length.clamp(0, _maxUserAgentLength),
      ),
      'isMobileDevice': MobileDetectionService.isMobileDevice,
      'isAndroid': MobileDetectionService.isAndroid,
      'isIOS': MobileDetectionService.isIOS,
      'isRunningAsPWA': MobileDetectionService.isRunningAsPWA,
      'isRunningInBrowser': MobileDetectionService.isRunningInBrowser,
      'updatedAt': now,
      'lastSeenAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
    _logInfo('upsertSubscription write complete');
  }

  Future<void> _disableDuplicateTokenDocs({required String token}) async {
    final collection = _subscriptionsCollection();
    final keepId = _installationId;
    if (collection == null || keepId == null) return;
    final dupes = await collection.where('token', isEqualTo: token).get();
    _logInfo('disableDuplicateTokenDocs matches=${dupes.docs.length}');
    if (dupes.docs.length <= 1) return;
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    for (final doc in dupes.docs) {
      if (doc.id == keepId) continue;
      batch.set(doc.reference, {
        'enabled': false,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
    _logInfo('disableDuplicateTokenDocs complete');
  }

  void _logInfo(String message) {
    debugPrint('$_logPrefix $message');
  }

  void _logWarn(String message) {
    debugPrint('$_logPrefix $message');
  }

  void _logError(String message, [Object? stackTrace]) {
    debugPrint('$_logPrefix $message');
    if (stackTrace != null) {
      debugPrint('$_logPrefix stack: $stackTrace');
    }
  }
}
