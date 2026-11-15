import 'package:flutter/foundation.dart';

import 'event_schedule_utils.dart';

import 'browser_timezone_utils_stub.dart'
    if (dart.library.js_interop) 'browser_timezone_utils_web.dart' as impl;

/// Resolves a raw IANA timezone id to a known zone, falling back to [fallback].
@visibleForTesting
String resolveDetectedTimeZone(String? raw, {String fallback = 'UTC'}) {
  return EventScheduleUtils.normalizeTimeZone(raw) ?? fallback;
}

/// Loads the device timezone on native so [detectIanaTimeZone] can answer
/// synchronously. Call once before `runApp`; a no-op on web.
Future<void> primeLocalTimeZone() => impl.primeLocalTimeZone();

@visibleForTesting
void debugSetDeviceTimeZone(String? value) =>
    impl.debugSetDeviceTimeZone(value);

/// Detects the user's IANA timezone, validated against the IANA database:
/// the browser's zone on web, the device's zone on native (after
/// [primeLocalTimeZone]).
///
/// Returns [fallback] when detection fails or the platform reports an unknown
/// zone id.
String detectIanaTimeZone({String fallback = 'UTC'}) {
  try {
    final raw = impl.readBrowserTimeZoneRaw()?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return resolveDetectedTimeZone(raw, fallback: fallback);
  } catch (_) {
    return fallback;
  }
}
