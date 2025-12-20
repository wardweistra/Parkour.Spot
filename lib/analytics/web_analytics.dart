// lib/analytics/web_analytics.dart
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// Helper function to call gtag via JS interop
@JS('eval')
external JSAny _eval(JSString code);

class WebAnalytics {
  static bool _initialized = false;

  static void init() {
    if (_initialized) {
      debugPrint('🔵 [GA] Already initialized, skipping');
      return;
    }
    _initialized = true;
    
    debugPrint('🔵 [GA] Initializing Google Analytics...');
    debugPrint('🔵 [GA] gtag available: $_hasGtag');
    
    if (!_hasGtag) {
      debugPrint('⚠️ [GA] gtag function not found. Make sure GA4 scripts are loaded in HTML.');
      return;
    }

    debugPrint('✅ [GA] Google Analytics initialized successfully');
    // Don't track initial page view here - let the router observer handle it
    // to avoid duplicate tracking
  }

  static void trackPageView({String? path}) {
    if (!_hasGtag) {
      debugPrint('⚠️ [GA] Cannot track page view: gtag not available');
      return;
    }

    final pagePath = path ?? _pathname;
    // Construct page_location from the path if provided, otherwise use current href
    // This ensures page_location matches page_path
    final pageLocation = path != null 
        ? '${web.window.location.origin}$path'
        : _href;
    
    debugPrint('📊 [GA] Tracking page_view: $pagePath');
    debugPrint('   └─ Location: $pageLocation');
    debugPrint('   └─ Title: $_title');

    _gtag('event', 'page_view', {
      'page_location': pageLocation,
      'page_path': pagePath,
      'page_title': _title,
    });
  }

  static void trackEvent(String name, Map<String, Object?> params) {
    if (!_hasGtag) {
      debugPrint('⚠️ [GA] Cannot track event "$name": gtag not available');
      return;
    }

    debugPrint('📊 [GA] Tracking event: $name');
    debugPrint('   └─ Params: $params');

    _gtag('event', name, params);
  }

  static void updateConsent(Map<String, String> consent) {
    if (!_hasGtag) {
      debugPrint('⚠️ [GA] Cannot update consent: gtag not available');
      return;
    }

    debugPrint('🔒 [GA] Updating consent: $consent');
    _gtag('consent', 'update', consent);
  }

  static bool get _hasGtag {
    try {
      // Check if gtag exists using eval (WASM-compatible)
      final checkCode = 'typeof window.gtag !== "undefined"'.toJS;
      final result = _eval(checkCode);
      final hasGtag = (result as JSBoolean).toDart;
      
      if (kDebugMode) {
        debugPrint('🔍 [GA] Checking gtag availability: $hasGtag');
        if (hasGtag) {
          try {
            final idCode = 'window.GA_MEASUREMENT_ID || ""'.toJS;
            final idResult = _eval(idCode);
            final measurementId = (idResult as JSString).toDart;
            debugPrint('   └─ Measurement ID: $measurementId');
          } catch (_) {
            debugPrint('   └─ Measurement ID: (not found)');
          }
        }
      }
      return hasGtag;
    } catch (e) {
      debugPrint('❌ [GA] Error checking gtag availability: $e');
      return false;
    }
  }

  static String get _href => web.window.location.href;

  static String get _pathname => web.window.location.pathname;

  static String get _title => web.window.document.title;

  static void _gtag(String command, String a1, [Map<String, Object?>? a2]) {
    try {
      if (a2 == null) {
        debugPrint('   └─ Calling gtag("$command", "$a1")');
        // Call gtag using eval (WASM-compatible)
        final code = 'window.gtag("$command", "$a1")'.toJS;
        _eval(code);
      } else {
        debugPrint('   └─ Calling gtag("$command", "$a1", $a2)');
        // Convert params to JSON and call gtag
        final jsonParams = _mapToJson(a2);
        final code = 'window.gtag("$command", "$a1", $jsonParams)'.toJS;
        _eval(code);
      }
      debugPrint('✅ [GA] gtag call completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ [GA] Error calling gtag: $e');
      debugPrint('   └─ Stack trace: $stackTrace');
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


