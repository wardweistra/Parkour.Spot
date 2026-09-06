import 'package:firebase_analytics/firebase_analytics.dart';

/// Native analytics via Firebase Analytics (web uses gtag).
class WebAnalytics {
  static FirebaseAnalytics? _analytics;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;
    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {
      _analytics = null;
    }
  }

  static void trackPageView({String? path}) {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      analytics.logScreenView(
        screenName: path ?? 'unknown',
        screenClass: 'Flutter',
      );
    } catch (_) {}
  }

  static void trackEvent(String name, Map<String, Object?> params) {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      final cleaned = <String, Object>{};
      for (final entry in params.entries) {
        final v = entry.value;
        if (v == null) continue;
        if (v is String || v is num || v is bool) {
          cleaned[entry.key] = v;
        } else {
          cleaned[entry.key] = v.toString();
        }
      }
      analytics.logEvent(name: name, parameters: cleaned);
    } catch (_) {}
  }

  static void updateConsent(Map<String, String> consent) {
    // Consent Mode is web/gtag-specific; no-op on native for Phase 1.
  }
}
