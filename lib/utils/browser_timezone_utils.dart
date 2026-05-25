import 'package:flutter/foundation.dart';

import 'event_schedule_utils.dart';

import 'browser_timezone_utils_stub.dart'
    if (dart.library.js_interop) 'browser_timezone_utils_web.dart' as impl;

/// Resolves a raw IANA timezone id to a known zone, falling back to [fallback].
@visibleForTesting
String resolveDetectedTimeZone(String? raw, {String fallback = 'UTC'}) {
  return EventScheduleUtils.normalizeTimeZone(raw) ?? fallback;
}

/// Detects the browser's IANA timezone (web only), validated against the IANA database.
///
/// Returns [fallback] when not on web, when detection fails, or when the browser
/// reports an unknown zone id.
String detectIanaTimeZone({String fallback = 'UTC'}) {
  if (!kIsWeb) return fallback;
  try {
    final raw = impl.readBrowserTimeZoneRaw()?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return resolveDetectedTimeZone(raw, fallback: fallback);
  } catch (_) {
    return fallback;
  }
}
