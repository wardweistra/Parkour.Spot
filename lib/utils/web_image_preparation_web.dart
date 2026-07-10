import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'image_preparation.dart';

const double _jpegQuality = 0.85;

(int, int) _targetDimensions(int width, int height, int maxDimension) {
  if (width <= maxDimension && height <= maxDimension) {
    return (width, height);
  }
  if (width >= height) {
    return (maxDimension, (height * maxDimension / width).round());
  }
  return ((width * maxDimension / height).round(), maxDimension);
}

Future<Uint8List> _bitmapToJpegBytes(
  web.ImageBitmap bitmap,
  int width,
  int height,
) async {
  final canvas = web.OffscreenCanvas(width, height);
  final ctx = canvas.getContext('2d') as web.OffscreenCanvasRenderingContext2D;
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();

  final blob = await canvas
      .convertToBlob(
        web.ImageEncodeOptions(type: 'image/jpeg', quality: _jpegQuality),
      )
      .toDart;

  final buffer = await blob.arrayBuffer().toDart;
  return Uint8List.view(buffer.toDart);
}

Future<PreparedImage> _encodeElementAsJpeg(
  web.HTMLImageElement element,
  int width,
  int height,
  int maxDimension,
) async {
  final (targetWidth, targetHeight) = _targetDimensions(
    width,
    height,
    maxDimension,
  );

  final bitmap = await web.window
      .createImageBitmap(
        element,
        web.ImageBitmapOptions(
          resizeWidth: targetWidth,
          resizeHeight: targetHeight,
          resizeQuality: 'high',
        ),
      )
      .toDart;

  final bytes = await _bitmapToJpegBytes(bitmap, targetWidth, targetHeight);
  return PreparedImage(bytes: bytes, contentType: 'image/jpeg');
}

Future<PreparedImage?> _prepareDecodedElement({
  required web.HTMLImageElement element,
  required Uint8List bytes,
  required int maxDimension,
  String? mimeType,
}) async {
  final width = element.naturalWidth;
  final height = element.naturalHeight;
  if (width <= 0 || height <= 0) {
    throw ImagePreparationException(
      'This image appears to be corrupt or unreadable. Please try a different photo.',
    );
  }
  if (bytes.isEmpty) {
    throw ImagePreparationException('Image data is empty.');
  }

  final contentType = detectContentType(bytes);
  if (contentType.isEmpty) {
    throw ImagePreparationException(
      'Unsupported image format. Please use JPEG, PNG, GIF, WebP, or HEIC.',
    );
  }

  final needsResize = width > maxDimension || height > maxDimension;
  final needsJpegNormalize =
      contentType == 'image/png' || contentType == 'image/webp';

  if (contentType == 'image/gif') {
    if (needsResize) {
      return null;
    }
    return PreparedImage(bytes: bytes, contentType: contentType);
  }

  if (!needsResize && !needsJpegNormalize) {
    final trimmedMime = mimeType?.trim();
    if (trimmedMime != null && trimmedMime.isNotEmpty) {
      return PreparedImage(bytes: bytes, contentType: trimmedMime);
    }
    return PreparedImage(bytes: bytes, contentType: contentType);
  }

  try {
    return await _encodeElementAsJpeg(element, width, height, maxDimension);
  } catch (_) {
    return null;
  }
}

/// Validates and prepares a picked image using the browser's async decoder.
///
/// Returns a [PreparedImage] when preparation succeeds in the browser.
/// Returns `null` to fall back to the Dart isolate pipeline (e.g. LibreWolf
/// canvas blocking, animated GIF resize, or unsupported cases).
Future<PreparedImage?> preparePickedImageOnWeb({
  required String blobUrl,
  required String? mimeType,
  required Future<Uint8List> Function() readBytes,
  required int maxDimension,
}) async {
  if (blobUrl.isEmpty) {
    return null;
  }

  final element = web.HTMLImageElement()..src = blobUrl;

  late Uint8List bytes;
  try {
    final results = await Future.wait<Object?>([
      element.decode().toDart,
      readBytes(),
    ]);
    bytes = results[1]! as Uint8List;
  } catch (_) {
    throw ImagePreparationException(
      'This image appears to be corrupt or unreadable. Please try a different photo.',
    );
  }

  return _prepareDecodedElement(
    element: element,
    bytes: bytes,
    maxDimension: maxDimension,
    mimeType: mimeType,
  );
}

/// Prepares downloaded image bytes using the browser's async decoder.
///
/// Returns `null` to fall back to the Dart isolate pipeline.
Future<PreparedImage?> prepareDownloadedImageOnWeb({
  required Uint8List bytes,
  required int maxDimension,
}) async {
  if (bytes.isEmpty) {
    return null;
  }

  final blob = web.Blob([bytes.toJS].toJS);
  final blobUrl = web.URL.createObjectURL(blob);
  final element = web.HTMLImageElement()..src = blobUrl;

  try {
    await element.decode().toDart;
    return _prepareDecodedElement(
      element: element,
      bytes: bytes,
      maxDimension: maxDimension,
    );
  } catch (_) {
    return null;
  } finally {
    web.URL.revokeObjectURL(blobUrl);
  }
}
