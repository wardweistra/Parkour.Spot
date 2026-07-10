import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show ImageSource, XFile;

import 'image_preparation.dart';
import 'ui_yield.dart';
import 'web_image_preparation_stub.dart'
    if (dart.library.js_interop) 'web_image_preparation_web.dart' as web_image;

/// Default longest-edge cap for user-selected photos.
const int kDefaultMaxImageDimension = 2048;

/// Default JPEG quality for user-selected photos.
const int kDefaultJpegQuality = 85;

enum ImagePickPhase { reading, processing }

typedef ImagePickProgressCallback = void Function({
  required int current,
  required int total,
  required ImagePickPhase phase,
});

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

int _effectiveMaxDimension(int maxDimension) =>
    maxDimension > 0 ? maxDimension : kDefaultMaxImageDimension;

/// Validates, optionally resizes, and re-encodes bytes picked on web.
///
/// On mobile this is a no-op when [kIsWeb] is false and [jpegQuality] /
/// [maxDimension] are left at zero (native [image_picker] already processed
/// the file). On web, validates decodes and resizes when needed but does not
/// force JPEG re-encode when the source is already small enough.
Future<PreparedImage> preparePickedImageBytes(
  Uint8List bytes, {
  int maxDimension = 0,
  int jpegQuality = 0,
}) {
  if (kIsWeb) {
    return prepareImageForUpload(
      bytes,
      maxDimension: _effectiveMaxDimension(maxDimension),
      jpegQuality: 0,
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

Future<PreparedImage> _preparePickedFile(
  XFile file, {
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
  ImagePickProgressCallback? onProgress,
  required int current,
  required int total,
}) async {
  onProgress?.call(
    current: current,
    total: total,
    phase: ImagePickPhase.processing,
  );
  await yieldToUi();

  if (kIsWeb) {
    final webPrepared = await web_image.preparePickedImageOnWeb(
      blobUrl: file.path,
      mimeType: file.mimeType,
      readBytes: file.readAsBytes,
      maxDimension: _effectiveMaxDimension(maxDimension),
    );
    if (webPrepared != null) {
      return webPrepared;
    }
  }

  onProgress?.call(
    current: current,
    total: total,
    phase: ImagePickPhase.reading,
  );
  await yieldToUi();

  final bytes = await file.readAsBytes();
  await yieldToUi();

  onProgress?.call(
    current: current,
    total: total,
    phase: ImagePickPhase.processing,
  );
  await yieldToUi();

  return preparePickedImageBytes(
    bytes,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );
}

/// Prepares already-picked files (call after showing a loading indicator).
Future<List<PreparedImage>> preparePickedFiles(
  List<XFile> pickedFiles, {
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
  int? maxImages,
  ImagePickProgressCallback? onProgress,
}) async {
  if (pickedFiles.isEmpty) {
    return const <PreparedImage>[];
  }

  final total = maxImages != null
      ? pickedFiles.length.clamp(0, maxImages)
      : pickedFiles.length;
  final preparedImages = <PreparedImage>[];

  for (var i = 0; i < total; i++) {
    preparedImages.add(
      await _preparePickedFile(
        pickedFiles[i],
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
        onProgress: onProgress,
        current: i + 1,
        total: total,
      ),
    );
  }

  return preparedImages;
}

/// Picks gallery images, then prepares them off the main thread.
Future<List<PreparedImage>> pickAndPrepareGalleryImages({
  ImagePicker? picker,
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
  int? maxImages,
  ImagePickProgressCallback? onProgress,
}) async {
  final pickedFiles = await pickImagesFromGallery(
    picker: picker,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );
  return preparePickedFiles(
    pickedFiles,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
    maxImages: maxImages,
    onProgress: onProgress,
  );
}

/// Picks a camera image and prepares it off the main thread.
Future<PreparedImage?> pickAndPrepareCameraImage({
  ImagePicker? picker,
  int maxDimension = kDefaultMaxImageDimension,
  int jpegQuality = kDefaultJpegQuality,
  ImagePickProgressCallback? onProgress,
}) async {
  final pickedFile = await pickImage(
    source: ImageSource.camera,
    picker: picker,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  );
  if (pickedFile == null) {
    return null;
  }

  await yieldToUi();

  return _preparePickedFile(
    pickedFile,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
    onProgress: onProgress,
    current: 1,
    total: 1,
  );
}

String imagePickProgressLabel(int current, int total) => '($current / $total)';
