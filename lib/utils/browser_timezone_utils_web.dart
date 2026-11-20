import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _JSDateTimeFormat._(JSObject _) implements JSObject {
  external _JSDateTimeFormat();
  external _JSResolvedDateTimeFormatOptions resolvedOptions();
}

@JS()
extension type _JSResolvedDateTimeFormatOptions._(JSObject _)
    implements JSObject {
  external String get timeZone;
}

String? readBrowserTimeZoneRaw() {
  return _JSDateTimeFormat().resolvedOptions().timeZone;
}

/// Web: the browser answers synchronously, nothing to load up front.
Future<void> primeLocalTimeZone() async {}

void debugSetDeviceTimeZone(String? value) {}
