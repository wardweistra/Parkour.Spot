import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _JSDateTimeFormat._(JSObject _) implements JSObject {
  external _JSDateTimeFormat();
  external _JSResolvedDateTimeFormatOptions resolvedOptions();
}

@JS()
extension type _JSResolvedDateTimeFormatOptions._(JSObject _) implements JSObject {
  external String get timeZone;
}

String? readBrowserTimeZoneRaw() {
  return _JSDateTimeFormat().resolvedOptions().timeZone;
}
