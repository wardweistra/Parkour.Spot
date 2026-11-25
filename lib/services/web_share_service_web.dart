import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'mobile_detection_service.dart';

/// Result of attempting [Web Share API](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/share)
/// on mobile web.
enum WebShareOutcome {
  /// Native share completed; do not copy or show clipboard snackbars.
  shared,

  /// User dismissed the sheet ([AbortError]); do not copy or show errors.
  cancelled,

  /// Use clipboard fallback (not mobile web, unsupported, or other error).
  fallback,
}

/// Mobile web: prefers `navigator.share` with [ShareData]; otherwise callers
/// should copy to clipboard.
class WebShareService {
  WebShareService._();

  /// Invokes Web Share when `kIsWeb` and the browser reports a mobile user agent.
  /// (Touch desktops and short windows use [WebShareOutcome.fallback] so clipboard
  /// copy and snackbars still run.)
  /// [text] must not include [url]—callers pass [ShareLinkText.shareLabel] while
  /// the clipboard string uses [ShareLinkText.clipboardText].
  static Future<WebShareOutcome> tryShareLink({
    required String text,
    required String url,
  }) async {
    if (!kIsWeb || !MobileDetectionService.isMobileUserAgent) {
      return WebShareOutcome.fallback;
    }

    try {
      final data = web.ShareData(title: text, text: text, url: url);
      final nav = web.window.navigator;
      if (!nav.canShare(data)) {
        return WebShareOutcome.fallback;
      }
      await nav.share(data).toDart;
      return WebShareOutcome.shared;
    } catch (e) {
      if (_isAbortError(e)) {
        return WebShareOutcome.cancelled;
      }
      return WebShareOutcome.fallback;
    }
  }

  /// Shares an image file (Web Share level 2) where the browser supports
  /// sharing files, which on phones offers Instagram, WhatsApp and similar
  /// apps directly. Elsewhere the image is downloaded and the outcome is
  /// [WebShareOutcome.fallback] so callers can say where it went.
  static Future<WebShareOutcome> tryShareImage({
    required Uint8List bytes,
    required String fileName,
    required String text,
    String mimeType = 'image/jpeg',
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final file = web.File(
      [blob].toJS,
      fileName,
      web.FilePropertyBag(type: mimeType),
    );
    try {
      final data = web.ShareData(files: [file].toJS, text: text);
      final nav = web.window.navigator;
      if (MobileDetectionService.isMobileUserAgent && nav.canShare(data)) {
        await nav.share(data).toDart;
        return WebShareOutcome.shared;
      }
    } catch (e) {
      if (_isAbortError(e)) {
        return WebShareOutcome.cancelled;
      }
    }
    _download(blob, fileName);
    return WebShareOutcome.fallback;
  }

  static void _download(web.Blob blob, String fileName) {
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// User dismissed the share sheet; avoid clipboard fallback. Avoids `is` checks
  /// on JS interop types (see invalid_runtime_check_with_js_interop_types).
  static bool _isAbortError(Object error) {
    return error.toString().contains('AbortError');
  }
}
