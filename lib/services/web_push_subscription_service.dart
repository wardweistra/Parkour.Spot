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
    _isSupported = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    _platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ios'
                    : defaultTargetPlatform.name));
  }

  static const _installationIdPrefsKey = 'web_push_installation_id';
  static const _androidPermissionRequestedPrefsKey =
      'android_push_permission_requested';
  static const _maxUserAgentLength = 600;

  static bool get _isNativeAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
  StreamSubscription<String>? _registeredSub;

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
      await _registeredSub?.cancel();
      _registeredSub = null;
      notifyListeners();
      return;
    }
    await refresh();
    _listenRegistrations();
  }

  /// Keeps the stored Firebase Installation ID (FID) current when FCM
  /// re-registers this app instance on its own (FID change, routine sync, or
  /// a web `pushsubscriptionchange`). FIDs from our own [_registerAndGetFid]
  /// calls arrive while [_isBusy] and are stored by that flow instead.
  void _listenRegistrations() {
    if (!_isSupported || _uid == null) return;
    _registeredSub?.cancel();
    _registeredSub = _messaging.onRegistered.listen((fid) async {
      if (_uid == null || fid.isEmpty || _isBusy) return;
      try {
        await _upsertSubscription(fid: fid, enabled: true);
        await _disableDuplicateFidDocs(fid: fid);
        _isSubscribed = true;
        notifyListeners();
      } catch (e) {
        debugPrint('FCM registration upsert failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _registeredSub?.cancel();
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
      final fid = await _registerAndGetFid();
      if (fid == null || fid.isEmpty) {
        _isSubscribed = false;
        return;
      }
      await _upsertSubscription(fid: fid, enabled: true);
      await _disableDuplicateFidDocs(fid: fid);
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
      if (_isNativeAndroid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_androidPermissionRequestedPrefsKey, true);
      }
      _permissionState = _mapPermission(settings.authorizationStatus);
      if (_permissionState != WebPushPermissionState.authorized) {
        _isSubscribed = false;
        return;
      }
      final fid = await _registerAndGetFid();
      if (fid == null || fid.isEmpty) {
        _isSubscribed = false;
        _lastError ??= kIsWeb
            ? 'No push registration available for this browser.'
            : 'No push registration available for this device.';
        return;
      }
      await _upsertSubscription(fid: fid, enabled: true);
      await _disableDuplicateFidDocs(fid: fid);
      _isSubscribed = true;
      _listenRegistrations();
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
        await _messaging.unregister();
      } catch (_) {}
      await _upsertSubscription(fid: null, enabled: false);
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
    } catch (e) {
      _lastError = e.toString();
      _isSubscribed = false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Registers this app instance with FCM and returns its Firebase
  /// Installation ID (FID), the direct-send target stored for the backend.
  ///
  /// [FirebaseMessaging.register] reports the FID only through
  /// [FirebaseMessaging.onRegistered], which emits after every register call,
  /// even when the instance is already registered. Subscribe before calling
  /// it so the event cannot be missed.
  Future<String?> _registerAndGetFid() async {
    try {
      await _awaitFirebaseMessagingServiceWorkerReady();
      String? vapidKey;
      if (kIsWeb) {
        vapidKey = AppConfig.firebaseWebPushVapidKey.trim();
        if (vapidKey.isEmpty) {
          _lastError = 'Missing FIREBASE_WEB_PUSH_VAPID_KEY configuration.';
          return null;
        }
      }
      const timeout = Duration(seconds: 12);
      final registered = _messaging.onRegistered.first.timeout(timeout);
      try {
        // Native FCM ignores the VAPID key.
        await _messaging.register(vapidKey: vapidKey).timeout(timeout);
      } catch (_) {
        // Don't leave the pending onRegistered wait to fail unhandled.
        unawaited(registered.then((_) {}, onError: (_) {}));
        rethrow;
      }
      return await registered;
    } on TimeoutException {
      _lastError =
          'Timed out while checking push registration. Please try again.';
      return null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Ensures the active service worker is ready before registering. Registering
  /// too early (e.g. right after first frame) can associate the FCM
  /// registration with the wrong service worker so **foreground** JS still receives
  /// messages but **background** push (service worker) does not — especially
  /// on Android PWAs after eager startup sync.
  Future<void> _awaitFirebaseMessagingServiceWorkerReady() async {
    if (!kIsWeb) return;
    await awaitBrowserServiceWorkerReady();
  }

  Future<WebPushPermissionState> _readPermissionState() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      final state = _mapPermission(settings.authorizationStatus);
      // Android has no "not determined" state: FCM reports `denied` until the
      // POST_NOTIFICATIONS permission is granted, even if we never asked.
      // Only treat it as blocked once we've actually prompted on this install.
      if (_isNativeAndroid && state == WebPushPermissionState.denied) {
        final prefs = await SharedPreferences.getInstance();
        final requested =
            prefs.getBool(_androidPermissionRequestedPrefsKey) ?? false;
        if (!requested) return WebPushPermissionState.notDetermined;
      }
      return state;
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
      case AuthorizationStatus.deniedPermanently:
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

  /// Stores this installation's push registration. Writing [fid] also clears
  /// the legacy `token` left by app versions that used registration tokens,
  /// so the backend switches this installation to FID sends.
  Future<void> _upsertSubscription({
    required bool enabled,
    String? fid,
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
      'fid': fid,
      'token': null,
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

  Future<void> _disableDuplicateFidDocs({required String fid}) async {
    final collection = _subscriptionsCollection();
    final keepId = _installationId;
    if (collection == null || keepId == null) return;
    final dupes = await collection.where('fid', isEqualTo: fid).get();
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
