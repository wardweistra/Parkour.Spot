import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show ImageSource, XFile;

import 'image_preparation.dart';

/// Default longest-edge cap for user-selected photos.
const int kDefaultMaxImageDimension = 2048;

/// Default JPEG quality for user-selected photos.
const int kDefaultJpegQuality = 85;

/// Picks multiple gallery images without triggering browser canvas re-encoding
/// on web (which breaks under Firefox/LibreWolf fingerprinting protection).
///
/// On mobile, native resizing/compression is used via [image_picker].
Future<List<XFile>> pickImagesFromGallery({
  ImagePicker? picker,
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
}) {
  final imagePicker = picker ?? ImagePicker();
  if (kIsWeb) {
    return imagePicker.pickMultiImage();
  }
  return imagePicker.pickMultiImage(
    maxWidth: maxDimension.toDouble(),
    maxHeight: maxDimension.toDouble(),
    imageQuality: jpegQuality,
  );
}

/// Picks a single image from the camera or gallery without browser canvas
/// re-encoding on web.
Future<XFile?> pickImage({
  required ImageSource source,
  ImagePicker? picker,
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
}) {
  final imagePicker = picker ?? ImagePicker();
  if (kIsWeb) {
    return imagePicker.pickImage(source: source);
  }
  return imagePicker.pickImage(
    source: source,
    maxWidth: maxDimension.toDouble(),
    maxHeight: maxDimension.toDouble(),
    imageQuality: jpegQuality,
  );
}

/// Validates, optionally resizes, and re-encodes bytes picked on web.
///
/// On mobile this is a no-op when [kIsWeb] is false and [jpegQuality] /
/// [maxDimension] are left at zero (native [image_picker] already processed
/// the file). On web, always pass the default dimension/quality constants.
Future<PreparedImage> preparePickedImageBytes(
  Uint8List bytes, {
  int maxDimension = 0,
  int jpegQuality = 0,
}) {
  if (kIsWeb) {
    return prepareImageForUpload(
      bytes,
      maxDimension: maxDimension > 0 ? maxDimension : kDefaultMaxImageDimension,
      jpegQuality: jpegQuality > 0 ? jpegQuality : kDefaultJpegQuality,
    );
  }
  if (maxDimension > 0 || jpegQuality > 0) {
    return prepareImageForUpload(
      bytes,
      maxDimension: maxDimension,
      jpegQuality: jpegQuality,
    );
  }
  return prepareImageForUpload(bytes);
}
