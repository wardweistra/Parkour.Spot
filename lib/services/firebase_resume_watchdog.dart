import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/browser_location.dart';

/// Reloads the web app when Firebase token plumbing is stuck after a resume.
///
/// On Android, a PWA that sat in the background for a while can come back with
/// the Firebase JS SDK wedged: App Check's reCAPTCHA Enterprise exchange never
/// settles, and the SDK caches that in-flight promise, so every later
/// `getToken()` waits on it forever. Auth refreshes, Firestore and callables
/// all attach an App Check token, so the whole app stops getting data until
/// the page is reloaded.
///
/// After the page has been hidden for [minHiddenDuration], this asks Auth and
/// App Check for a token. A healthy SDK answers from memory or one short
/// request. If either is still pending after [probeTimeout], the page reloads,
/// at most once per [minReloadInterval] so a really slow network cannot cause
/// a reload loop.
class FirebaseResumeWatchdog {
  FirebaseResumeWatchdog._();

  static const minHiddenDuration = Duration(seconds: 30);
  static const probeTimeout = Duration(seconds: 20);
  static const minReloadInterval = Duration(minutes: 5);

  static const _lastReloadAtKey = 'firebaseResumeWatchdog.lastReloadAt';
  static const _lastReloadReasonKey = 'firebaseResumeWatchdog.lastReloadReason';

  static bool _started = false;
  static bool _appCheckActive = false;
  static DateTime? _hiddenAt;
  static bool _checking = false;
  static String? _lastCheck;

  /// Starts watching page visibility. Web only; a no-op elsewhere.
  static void start({required bool appCheckActive}) {
    if (!kIsWeb || _started) return;
    _started = true;
    _appCheckActive = appCheckActive;
    if (browserVisibilityState() == 'hidden') {
      _hiddenAt = DateTime.now();
    }
    listenBrowserVisibility(_onVisibilityChange);
  }

  /// State for the admin Firebase connectivity page.
  static Map<String, String> diagnostics() => {
        'watchdog.active': _started.toString(),
        'watchdog.appCheckChecked': _appCheckActive.toString(),
        'watchdog.lastCheck': _lastCheck ?? '(none since load)',
        'watchdog.lastReloadAt':
            browserSessionStorageGet(_lastReloadAtKey) ?? '(none)',
        'watchdog.lastReloadReason':
            browserSessionStorageGet(_lastReloadReasonKey) ?? '(none)',
      };

  static void _onVisibilityChange(bool visible) {
    final now = DateTime.now();
    if (!visible) {
      _hiddenAt = now;
      return;
    }
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || now.difference(hiddenAt) < minHiddenDuration) {
      return;
    }
    unawaited(_checkAfterResume(now.difference(hiddenAt)));
  }

  static Future<void> _checkAfterResume(Duration hiddenFor) async {
    if (_checking) return;
    // Offline: requests fail fast instead of hanging; nothing to recover.
    if (browserNavigatorOnLine() == false) {
      _lastCheck = '${_stamp()} skipped (offline)';
      return;
    }
    _checking = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final stalled = await findStalledProbes({
        if (_appCheckActive)
          'appCheck': () => FirebaseAppCheck.instance.getToken(),
        if (user != null) 'auth': () => user.getIdToken(),
      }, probeTimeout);

      final hiddenMin = hiddenFor.inMinutes;
      if (stalled.isEmpty) {
        _lastCheck = '${_stamp()} ok (hidden ${hiddenMin}m)';
        return;
      }

      final reason =
          'stalled: ${stalled.join(', ')} after ${probeTimeout.inSeconds}s '
          '(hidden ${hiddenMin}m)';
      final lastReloadAt = DateTime.tryParse(
        browserSessionStorageGet(_lastReloadAtKey) ?? '',
      );
      final now = DateTime.now();
      if (!shouldReload(lastReloadAt: lastReloadAt, now: now)) {
        _lastCheck = '${_stamp()} $reason; not reloading (reloaded recently)';
        debugPrint('FirebaseResumeWatchdog: $_lastCheck');
        return;
      }

      _lastCheck = '${_stamp()} $reason; reloading';
      debugPrint('FirebaseResumeWatchdog: $_lastCheck');
      browserSessionStorageSet(_lastReloadAtKey, now.toUtc().toIso8601String());
      browserSessionStorageSet(_lastReloadReasonKey, reason);
      browserReload();
    } finally {
      _checking = false;
    }
  }

  static String _stamp() => DateTime.now().toUtc().toIso8601String();

  /// Whether a reload is allowed, given when the last watchdog reload was.
  @visibleForTesting
  static bool shouldReload({
    required DateTime? lastReloadAt,
    required DateTime now,
  }) {
    if (lastReloadAt == null) return true;
    return now.difference(lastReloadAt) >= minReloadInterval;
  }

  /// Runs all [probes] in parallel; returns the names of those still pending
  /// after [timeout]. A probe that throws has answered, so it is not stalled:
  /// only a hang means the SDK is wedged.
  @visibleForTesting
  static Future<List<String>> findStalledProbes(
    Map<String, Future<Object?> Function()> probes,
    Duration timeout,
  ) async {
    final results = await Future.wait(
      probes.entries.map((entry) async {
        try {
          await entry.value().timeout(timeout);
          return null;
        } on TimeoutException {
          return entry.key;
        } catch (_) {
          return null;
        }
      }),
    );
    return results.whereType<String>().toList();
  }
}
