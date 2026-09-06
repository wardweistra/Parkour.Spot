import 'browser_location_stub.dart'
    if (dart.library.js_interop) 'browser_location_web.dart' as impl;

/// Browser `location.href`, or null when not on web.
String? browserHref() => impl.readBrowserHref();

String? browserHostname() => impl.readBrowserHostname();

String? browserPathname() => impl.readBrowserPathname();

String? browserOrigin() => impl.readBrowserOrigin();

String? browserProtocol() => impl.readBrowserProtocol();

String? browserUserAgent() => impl.readBrowserUserAgent();

String? browserLanguage() => impl.readBrowserLanguage();

List<String> browserLanguages() => impl.readBrowserLanguages();

void browserReload() => impl.reloadBrowserLocation();

void setDocumentTitle(String title) => impl.setBrowserDocumentTitle(title);

String? documentTitle() => impl.readBrowserDocumentTitle();

bool? hasManifestLink() => impl.queryManifestLinkPresent();

bool? browserMatchMedia(String query) => impl.matchMediaMatches(query);

void updateBrowserPageMeta(String title, String description) =>
    impl.updateBrowserPageMeta(title, description);

Future<void> awaitBrowserServiceWorkerReady({
  Duration timeout = const Duration(seconds: 6),
}) =>
    impl.awaitServiceWorkerReady(timeout: timeout);
