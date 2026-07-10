import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:heic_to_png_jpg/heic_to_png_jpg.dart';
import 'package:image/image.dart' as img;

/// Result of preparing an image for upload.
/// Contains validated/converted bytes and the correct MIME type.
class PreparedImage {
  final Uint8List bytes;
  final String contentType;

  const PreparedImage({required this.bytes, required this.contentType});
}

/// Thrown when image validation or preparation fails.
class ImagePreparationException implements Exception {
  final String message;

  ImagePreparationException([this.message = 'Failed to process image.']);

  @override
  String toString() => 'ImagePreparationException: $message';
}

/// Detects HEIC/HEIF via ISO BMFF "ftyp" box.
/// Bytes 4-7 must be "ftyp", bytes 8-11 are the major brand.
bool isHeic(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // ftyp at offset 4
  if (bytes[4] != 0x66 || bytes[5] != 0x74 ||
      bytes[6] != 0x79 || bytes[7] != 0x70) {
    return false;
  }
  // Major brand at offset 8: heic, mif1, heix, hevx, msf1
  final b8 = bytes[8], b9 = bytes[9], b10 = bytes[10], b11 = bytes[11];
  // heic
  if (b8 == 0x68 && b9 == 0x65 && b10 == 0x69 && b11 == 0x63) return true;
  // mif1
  if (b8 == 0x6D && b9 == 0x69 && b10 == 0x66 && b11 == 0x31) return true;
  // heix
  if (b8 == 0x68 && b9 == 0x65 && b10 == 0x69 && b11 == 0x78) return true;
  // hevx
  if (b8 == 0x68 && b9 == 0x65 && b10 == 0x76 && b11 == 0x78) return true;
  // msf1
  if (b8 == 0x6D && b9 == 0x73 && b10 == 0x66 && b11 == 0x31) return true;
  return false;
}

/// Returns the MIME type if bytes represent a valid supported format,
/// or empty string if invalid/unsupported.
String detectContentType(Uint8List bytes) {
  if (bytes.length < 4) return '';

  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }

  // PNG
  if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4E && bytes[3] == 0x47) {
    return 'image/png';
  }

  // GIF
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return 'image/gif';
  }

  // WebP
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 &&
      bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }

  // HEIC
  if (isHeic(bytes)) return 'image/heic';

  return '';
}

/// Validates that bytes represent JPEG, PNG, GIF, or WebP.
/// Returns false for HEIC (use [isHeic] and convert separately) or unknown formats.
bool isValidImageFormat(Uint8List bytes) {
  final ct = detectContentType(bytes);
  return ct.isNotEmpty && ct != 'image/heic';
}

PreparedImage _prepareFromDecoded({
  required img.Image decoded,
  required Uint8List originalBytes,
  required String contentType,
  int maxDimension = 0,
  int jpegQuality = 0,
}) {
  if (contentType == 'image/gif') {
    return PreparedImage(bytes: originalBytes, contentType: contentType);
  }

  final needsResize = maxDimension > 0 &&
      (decoded.width > maxDimension || decoded.height > maxDimension);
  final needsJpegReencode =
      jpegQuality > 0 && contentType == 'image/jpeg';

  if (!needsResize && !needsJpegReencode) {
    return PreparedImage(bytes: originalBytes, contentType: contentType);
  }

  img.Image output = decoded;
  if (needsResize) {
    if (decoded.width >= decoded.height) {
      output = img.copyResize(
        decoded,
        width: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      output = img.copyResize(
        decoded,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  final quality = jpegQuality > 0 ? jpegQuality : 85;
  final jpegBytes = img.encodeJpg(output, quality: quality);
  return PreparedImage(
    bytes: Uint8List.fromList(jpegBytes),
    contentType: 'image/jpeg',
  );
}

class _PrepareImageRequest {
  final Uint8List bytes;
  final int maxDimension;
  final int jpegQuality;

  const _PrepareImageRequest({
    required this.bytes,
    required this.maxDimension,
    required this.jpegQuality,
  });
}

PreparedImage _prepareImageForUploadSync(_PrepareImageRequest request) {
  final bytes = request.bytes;
  if (bytes.isEmpty) {
    throw ImagePreparationException('Image data is empty.');
  }

  final contentType = detectContentType(bytes);
  if (contentType.isEmpty) {
    throw ImagePreparationException(
      'Unsupported image format. Please use JPEG, PNG, GIF, WebP, or HEIC.',
    );
  }

  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw ImagePreparationException(
      'This image appears to be corrupt or unreadable. Please try a different photo.',
    );
  }

  return _prepareFromDecoded(
    decoded: decoded,
    originalBytes: bytes,
    contentType: contentType,
    maxDimension: request.maxDimension,
    jpegQuality: request.jpegQuality,
  );
}

Map<String, Object?> _prepareImageForUploadWorker(Map<String, Object?> message) {
  try {
    final result = _prepareImageForUploadSync(
      _PrepareImageRequest(
        bytes: message['bytes']! as Uint8List,
        maxDimension: message['maxDimension']! as int,
        jpegQuality: message['jpegQuality']! as int,
      ),
    );
    return {
      'bytes': result.bytes,
      'contentType': result.contentType,
    };
  } on ImagePreparationException catch (e) {
    return {'error': e.message};
  } catch (_) {
    return {
      'error': 'Failed to process image. Please try a different photo.',
    };
  }
}

Future<PreparedImage> _prepareImageOffMainThread(
  Uint8List bytes, {
  int maxDimension = 0,
  int jpegQuality = 0,
}) async {
  final request = _PrepareImageRequest(
    bytes: bytes,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );

  if (kIsWeb) {
    // Prefer Isolate.run on web; compute's Map payload adds copy overhead.
    try {
      return await Isolate.run(() => _prepareImageForUploadSync(request));
    } catch (_) {
      // Fall back if workers are unavailable in this build target.
      return _prepareImageForUploadSync(request);
    }
  }

  final result = await compute(_prepareImageForUploadWorker, <String, Object?>{
    'bytes': bytes,
    'maxDimension': maxDimension,
    'jpegQuality': jpegQuality,
  });
  final error = result['error'] as String?;
  if (error != null) {
    throw ImagePreparationException(error);
  }
  return PreparedImage(
    bytes: result['bytes']! as Uint8List,
    contentType: result['contentType']! as String,
  );
}

/// Validates image bytes, converts HEIC to JPEG if needed, and returns
/// prepared bytes with correct contentType. Rejects invalid formats.
///
/// Supported input: JPEG, PNG, GIF, WebP, HEIC (converted to JPEG).
/// Throws [ImagePreparationException] for unsupported or corrupt images.
///
/// When [maxDimension] or [jpegQuality] are set, the image is decoded,
/// resized (longest edge capped), and re-encoded in Dart — avoiding browser
/// canvas APIs that break under privacy-focused browsers.
Future<PreparedImage> prepareImageForUpload(
  Uint8List bytes, {
  int maxDimension = 0,
  int jpegQuality = 0,
}) async {
  if (bytes.isEmpty) {
    throw ImagePreparationException(
      'Image data is empty.',
    );
  }

  // HEIC: convert to JPEG, then continue through the normal pipeline.
  if (isHeic(bytes)) {
    try {
      final jpegBytes = await HeicConverter.convertToJPG(
        heicData: bytes,
        quality: jpegQuality > 0 ? jpegQuality : 85,
      );
      if (jpegBytes.isEmpty) {
        throw ImagePreparationException(
          'Failed to convert HEIC image. Please try a different photo.',
        );
      }
      return prepareImageForUpload(
        jpegBytes,
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      );
    } catch (e) {
      if (e is ImagePreparationException) rethrow;
      throw ImagePreparationException(
        'Failed to process image. Please try a different photo.',
      );
    }
  }

  return _prepareImageOffMainThread(
    bytes,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );
}

/// Resizes image bytes for spot upload (e.g. when approving suggested photos).
/// Keeps aspect ratio, caps longest edge at [maxDimension], encodes as JPEG.
/// Use this to avoid memory/timeout issues with very large source images.
Uint8List? resizeImageForSpotUpload(
  Uint8List bytes, {
  int maxDimension = 2048,
  int jpegQuality = 85,
}) {
  if (bytes.isEmpty) return null;
  try {
    final contentType = detectContentType(bytes);
    if (contentType.isEmpty || contentType == 'image/heic') return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }

    return _prepareFromDecoded(
      decoded: decoded,
      originalBytes: bytes,
      contentType: contentType,
      maxDimension: maxDimension,
      jpegQuality: jpegQuality,
    ).bytes;
  } catch (_) {
    return null;
  }
}
