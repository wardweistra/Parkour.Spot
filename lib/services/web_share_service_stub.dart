import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

enum WebShareOutcome { shared, cancelled, fallback }

/// Native (non-web) share via the system share sheet.
class WebShareService {
  WebShareService._();

  static Future<WebShareOutcome> tryShareLink({
    required String text,
    required String url,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: '$text\n$url'),
      );
      if (result.status == ShareResultStatus.success) {
        return WebShareOutcome.shared;
      }
      if (result.status == ShareResultStatus.dismissed) {
        return WebShareOutcome.cancelled;
      }
      // unavailable — let callers fall back to clipboard
      return WebShareOutcome.fallback;
    } catch (_) {
      return WebShareOutcome.fallback;
    }
  }

  /// Shares an image file through the system share sheet.
  static Future<WebShareOutcome> tryShareImage({
    required Uint8List bytes,
    required String fileName,
    required String text,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
          fileNameOverrides: [fileName],
          text: text,
        ),
      );
      if (result.status == ShareResultStatus.success) {
        return WebShareOutcome.shared;
      }
      if (result.status == ShareResultStatus.dismissed) {
        return WebShareOutcome.cancelled;
      }
      return WebShareOutcome.fallback;
    } catch (_) {
      return WebShareOutcome.fallback;
    }
  }
}
