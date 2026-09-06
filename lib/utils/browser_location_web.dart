import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

String? readBrowserHref() => web.window.location.href;

String? readBrowserHostname() => web.window.location.hostname;

String? readBrowserPathname() => web.window.location.pathname;

String? readBrowserOrigin() => web.window.location.origin;

String? readBrowserProtocol() => web.window.location.protocol;

String? readBrowserUserAgent() => web.window.navigator.userAgent;

String? readBrowserLanguage() => web.window.navigator.language;

List<String> readBrowserLanguages() =>
    web.window.navigator.languages.toDart.map((s) => s.toDart).toList();

void reloadBrowserLocation() => web.window.location.reload();

void setBrowserDocumentTitle(String title) {
  web.document.title = title;
}

String? readBrowserDocumentTitle() => web.document.title;

bool? queryManifestLinkPresent() =>
    web.document.querySelector('link[rel="manifest"]') != null;

bool? matchMediaMatches(String query) =>
    web.window.matchMedia(query).matches;

void updateBrowserPageMeta(String title, String description) {
  web.document.title = title;

  final metaDescription =
      web.document.querySelector('meta[name="description"]');
  if (metaDescription != null) {
    metaDescription.setAttribute('content', description);
  } else {
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    meta.name = 'description';
    meta.content = description;
    web.document.head?.appendChild(meta);
  }

  final ogDescription =
      web.document.querySelector('meta[property="og:description"]');
  if (ogDescription != null) {
    ogDescription.setAttribute('content', description);
  }

  final twitterDescription =
      web.document.querySelector('meta[name="twitter:description"]');
  if (twitterDescription != null) {
    twitterDescription.setAttribute('content', description);
  }

  final ogTitle = web.document.querySelector('meta[property="og:title"]');
  if (ogTitle != null) {
    ogTitle.setAttribute('content', title);
  }

  final twitterTitle =
      web.document.querySelector('meta[name="twitter:title"]');
  if (twitterTitle != null) {
    twitterTitle.setAttribute('content', title);
  }
}

Future<void> awaitServiceWorkerReady({
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await web.window.navigator.serviceWorker.ready.toDart.timeout(timeout);
  } on TimeoutException {
    // Do not block forever if the SW is still settling.
  } catch (_) {
    // Non-fatal; registration may complete during getToken.
  }
}
