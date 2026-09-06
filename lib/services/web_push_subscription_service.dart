import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../utils/browser_location.dart';
import 'auth_service.dart';
import 'mobile_detection_service.dart';

enum WebPushPermissionState { unknown, notDetermined, denied, authorized }

class WebPushSubscriptionService extends ChangeNotifier {
  WebPushSubscriptionService() {
    _isSupported =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    _platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : (defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : defaultTargetPlatform.name));
  }

  static const _installationIdPrefsKey = 'web_push_installation_id';
  static const _maxUserAgentLength = 600;
  static const _maxLocaleLength = 16;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Uuid _uuid = const Uuid();

  late final String _platform;
  String? _uid;
  String? _installationId;
  bool _isBusy = false;
  bool _isSupported = false;
  bool _isSubscribed = false;
  String? _lastError;
  WebPushPermissionState _permissionState = WebPushPermissionState.unknown;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get isBusy => _isBusy;
  bool get isSupported => _isSupported;
  bool get isSubscribed => _isSubscribed;
  String? get lastError => _lastError;
  WebPushPermissionState get permissionState => _permissionState;
  String? get installationId => _installationId;

  Future<void> syncAuth(AuthService authService) async {
    final uid = authService.currentUser?.uid;
    if (_uid == uid) return;
    _uid = uid;
    _lastError = null;
    if (_uid == null) {
      _isSubscribed = false;
      _permissionState = WebPushPermissionState.unknown;
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      notifyListeners();
      return;
    }
    await refresh();
    _listenTokenRefresh();
  }

  void _listenTokenRefresh() {
    if (!_isSupported || _uid == null) return;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      if (_uid == null || token.isEmpty) return;
      try {
        await _upsertSubscription(token: token, enabled: true);
        await _disableDuplicateTokenDocs(token: token);
        _isSubscribed = true;
        notifyListeners();
      } catch (e) {
        debugPrint('FCM token refresh upsert failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!_isSupported) return;
    await _runBusy(() async {
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      _permissionState = await _readPermissionState();
      if (_uid == null ||
          _permissionState != WebPushPermissionState.authorized) {
        _isSubscribed = false;
        return;
      }
      final token = await _getCurrentToken();
      if (token == null || token.isEmpty) {
        _isSubscribed = false;
        return;
      }
      await _upsertSubscription(token: token, enabled: true);
      await _disableDuplicateTokenDocs(token: token);
      _isSubscribed = true;
    });
  }

  Future<bool> enableCurrentDevice() async {
    if (!_isSupported || _uid == null) return false;
    var success = false;
    await _runBusy(() async {
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      final settings = await _messaging.requestPermission();
      _permissionState = _mapPermission(settings.authorizationStatus);
      if (_permissionState != WebPushPermissionState.authorized) {
        _isSubscribed = false;
        return;
      }
      final token = await _getCurrentToken();
      if (token == null || token.isEmpty) {
        _isSubscribed = false;
        _lastError = kIsWeb
            ? 'No push token available for this browser.'
            : 'No push token available for this device.';
        return;
      }
      await _upsertSubscription(token: token, enabled: true);
      await _disableDuplicateTokenDocs(token: token);
      _isSubscribed = true;
      _listenTokenRefresh();
      success = true;
    });
    return success;
  }

  Future<bool> disableCurrentDevice() async {
    if (!_isSupported || _uid == null) return false;
    var success = false;
    await _runBusy(() async {
      _lastError = null;
      _installationId = await _getOrCreateInstallationId();
      try {
        await _messaging.deleteToken();
      } catch (_) {}
      await _upsertSubscription(token: null, enabled: false);
      _permissionState = await _readPermissionState();
      _isSubscribed = false;
      success = true;
    });
    return success;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
    } catch (e, _) {
      _lastError = e.toString();
      _isSubscribed = false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> _getCurrentToken() async {
    try {
      await _awaitFirebaseMessagingServiceWorkerReady();
      if (kIsWeb) {
        final vapidKey = AppConfig.firebaseWebPushVapidKey.trim();
        if (vapidKey.isEmpty) {
          _lastError = 'Missing FIREBASE_WEB_PUSH_VAPID_KEY configuration.';
          return null;
        }
        return await _messaging
            .getToken(vapidKey: vapidKey)
            .timeout(const Duration(seconds: 12));
      }
      // Native FCM: no VAPID key.
      return await _messaging.getToken().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _lastError =
          'Timed out while checking push registration. Please try again.';
      return null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Ensures the active service worker is ready before [getToken]. Calling
  /// [getToken] too early (e.g. right after first frame) can associate the FCM
  /// token with the wrong registration so **foreground** JS still receives
  /// messages but **background** push (service worker) does not — especially
  /// on Android PWAs after eager startup sync.
  Future<void> _awaitFirebaseMessagingServiceWorkerReady() async {
    if (!kIsWeb) return;
    await awaitBrowserServiceWorkerReady();
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
    final now = FieldValue.serverTimestamp();
    final locale = ui.PlatformDispatcher.instance.locale.languageCode
        .trim()
        .toLowerCase();
    final normalizedLocale = locale.isEmpty ? null : locale;
    final userAgent = browserUserAgent() ?? '';
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
  }

  Future<void> _disableDuplicateTokenDocs({required String token}) async {
    final collection = _subscriptionsCollection();
    final keepId = _installationId;
    if (collection == null || keepId == null) return;
    final dupes = await collection.where('token', isEqualTo: token).get();
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
  }
}
