import 'dart:typed_data';

import 'image_preparation.dart';

/// Non-web: always defers to the Dart image pipeline.
Future<PreparedImage?> preparePickedImageOnWeb({
  required String blobUrl,
  required String? mimeType,
  required Future<Uint8List> Function() readBytes,
  required int maxDimension,
}) async =>
    null;
