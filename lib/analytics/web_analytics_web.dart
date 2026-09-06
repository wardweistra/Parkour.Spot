// lib/analytics/web_analytics.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

// Helper function to call gtag via JS interop
@JS('eval')
external JSAny _eval(JSString code);

class WebAnalytics {
  static bool _initialized = false;

  static void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    
    if (!_hasGtag) {
      return;
    }

    // Don't track initial page view here - let the router observer handle it
    // to avoid duplicate tracking
  }

  static void trackPageView({String? path}) {
    if (!_hasGtag) {
      return;
    }

    final pagePath = path ?? _pathname;
    // Construct page_location from the path if provided, otherwise use current href
    // This ensures page_location matches page_path
    final pageLocation = path != null 
        ? '${web.window.location.origin}$path'
        : _href;

    _gtag('event', 'page_view', {
      'page_location': pageLocation,
      'page_path': pagePath,
      'page_title': _title,
    });
  }

  static void trackEvent(String name, Map<String, Object?> params) {
    if (!_hasGtag) {
      return;
    }

    _gtag('event', name, params);
  }

  static void updateConsent(Map<String, String> consent) {
    if (!_hasGtag) {
      return;
    }

    _gtag('consent', 'update', consent);
  }

  static bool get _hasGtag {
    try {
      // Check if gtag exists using eval (WASM-compatible)
      final checkCode = 'typeof window.gtag !== "undefined"'.toJS;
      final result = _eval(checkCode);
      final hasGtag = (result as JSBoolean).toDart;
      return hasGtag;
    } catch (e) {
      return false;
    }
  }

  static String get _href => web.window.location.href;

  static String get _pathname => web.window.location.pathname;

  static String get _title => web.window.document.title;

  static void _gtag(String command, String a1, [Map<String, Object?>? a2]) {
    try {
      if (a2 == null) {
        // Call gtag using eval (WASM-compatible)
        // Wrap in IIFE that returns true to avoid null/undefined type errors in dev mode
        final code = '(function() { window.gtag("$command", "$a1"); return true; })()'.toJS;
        _eval(code);
      } else {
        // Convert params to JSON and call gtag
        // Wrap in IIFE that returns true to avoid null/undefined type errors in dev mode
        final jsonParams = _mapToJson(a2);
        final code = '(function() { window.gtag("$command", "$a1", $jsonParams); return true; })()'.toJS;
        _eval(code);
      }
    } catch (e) {
      // Silently fail - analytics errors shouldn't break the app
    }
  }

  static String _mapToJson(Map<String, Object?> map) {
    // Convert map to JSON string for use in eval
    final buffer = StringBuffer();
    buffer.write('{');
    final entries = map.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":');
      final value = entry.value;
      if (value == null) {
        buffer.write('null');
      } else if (value is String) {
        buffer.write('"${value.replaceAll('"', '\\"')}"');
      } else if (value is num || value is bool) {
        buffer.write(value.toString());
      } else {
        buffer.write('"${value.toString().replaceAll('"', '\\"')}"');
      }
      if (i < entries.length - 1) buffer.write(',');
    }
    buffer.write('}');
    return buffer.toString();
  }
}


