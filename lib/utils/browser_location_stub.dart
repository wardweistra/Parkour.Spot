/// Non-web: no browser location.
String? readBrowserHref() => null;

String? readBrowserHostname() => null;

String? readBrowserPathname() => null;

String? readBrowserOrigin() => null;

String? readBrowserProtocol() => null;

String? readBrowserUserAgent() => null;

String? readBrowserLanguage() => null;

List<String> readBrowserLanguages() => const [];

void reloadBrowserLocation() {}

void setBrowserDocumentTitle(String title) {}

String? readBrowserDocumentTitle() => null;

bool? queryManifestLinkPresent() => null;

bool? matchMediaMatches(String query) => null;

void updateBrowserPageMeta(String title, String description) {}

Future<void> awaitServiceWorkerReady({
  Duration timeout = const Duration(seconds: 6),
}) async {}
