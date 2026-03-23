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

  /// Invokes Web Share when `kIsWeb` and [MobileDetectionService.isMobileDevice].
  /// [title] is used as `ShareData.title` and as the label before `👉` in `text`.
  static Future<WebShareOutcome> tryShareLink({
    required String title,
    required String url,
  }) async {
    if (!kIsWeb || !MobileDetectionService.isMobileDevice) {
      return WebShareOutcome.fallback;
    }

    final text = '$title 👉 $url';

    try {
      final data = web.ShareData(
        title: title,
        text: text,
        url: url,
      );
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

  /// User dismissed the share sheet; avoid clipboard fallback. Avoids `is` checks
  /// on JS interop types (see invalid_runtime_check_with_js_interop_types).
  static bool _isAbortError(Object error) {
    return error.toString().contains('AbortError');
  }
}
