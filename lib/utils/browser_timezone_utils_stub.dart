import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_timezone/flutter_timezone.dart';

String? _deviceTimeZone;

/// Native: the device's IANA timezone, once [primeLocalTimeZone] has run.
String? readBrowserTimeZoneRaw() => _deviceTimeZone;

/// Native: asks the OS for the device timezone once at startup so the
/// synchronous [readBrowserTimeZoneRaw] can answer from memory.
Future<void> primeLocalTimeZone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    _deviceTimeZone = info.identifier;
  } catch (e) {
    // No plugin (tests, unsupported platform): callers fall back to UTC.
    debugPrint('Device timezone lookup failed: $e');
  }
}

/// Test hook, exposed through `browser_timezone_utils.dart`.
void debugSetDeviceTimeZone(String? value) => _deviceTimeZone = value;
