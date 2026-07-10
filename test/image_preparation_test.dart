import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:parkour_spot/utils/image_preparation.dart';

Uint8List _minimalJpegBytes() {
  return Uint8List.fromList(
    img.encodeJpg(img.Image(width: 2, height: 2), quality: 90),
  );
}

Uint8List _minimalPngBytes() {
  return Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
}

void main() {
  group('isHeic', () {
    test('returns false for short bytes', () {
      expect(isHeic(Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])), false);
    });

    test('returns false when ftyp is missing', () {
      final bytes = Uint8List(20);
      bytes[8] = 0x68;
      bytes[9] = 0x65;
      bytes[10] = 0x69;
      bytes[11] = 0x63;
      expect(isHeic(bytes), false);
    });

    test('returns true for heic brand', () {
      final bytes = Uint8List(20);
      bytes[4] = 0x66;
      bytes[5] = 0x74;
      bytes[6] = 0x79;
      bytes[7] = 0x70;
      bytes[8] = 0x68;
      bytes[9] = 0x65;
      bytes[10] = 0x69;
      bytes[11] = 0x63;
      expect(isHeic(bytes), true);
    });

    test('returns true for mif1 brand', () {
      final bytes = Uint8List(20);
      bytes[4] = 0x66;
      bytes[5] = 0x74;
      bytes[6] = 0x79;
      bytes[7] = 0x70;
      bytes[8] = 0x6D;
      bytes[9] = 0x69;
      bytes[10] = 0x66;
      bytes[11] = 0x31;
      expect(isHeic(bytes), true);
    });
  });

  group('detectContentType', () {
    test('returns empty for short bytes', () {
      expect(detectContentType(Uint8List(3)), '');
    });

    test('returns image/jpeg for JPEG signature', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00, 0x00]);
      expect(detectContentType(bytes), 'image/jpeg');
    });

    test('returns image/png for PNG signature', () {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00]);
      expect(detectContentType(bytes), 'image/png');
    });

    test('returns image/gif for GIF signature', () {
      final bytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x00]);
      expect(detectContentType(bytes), 'image/gif');
    });

    test('returns image/webp for WebP signature', () {
      final bytes = Uint8List(20);
      bytes[0] = 0x52;
      bytes[1] = 0x49;
      bytes[2] = 0x46;
      bytes[3] = 0x46;
      bytes[8] = 0x57;
      bytes[9] = 0x45;
      bytes[10] = 0x42;
      bytes[11] = 0x50;
      expect(detectContentType(bytes), 'image/webp');
    });

    test('returns image/heic for HEIC signature', () {
      final bytes = Uint8List(20);
      bytes[4] = 0x66;
      bytes[5] = 0x74;
      bytes[6] = 0x79;
      bytes[7] = 0x70;
      bytes[8] = 0x68;
      bytes[9] = 0x65;
      bytes[10] = 0x69;
      bytes[11] = 0x63;
      expect(detectContentType(bytes), 'image/heic');
    });

    test('returns empty for unknown format', () {
      expect(detectContentType(Uint8List.fromList([0x00, 0x00, 0x00, 0x00])), '');
    });
  });

  group('isValidImageFormat', () {
    test('returns true for JPEG', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
      expect(isValidImageFormat(bytes), true);
    });

    test('returns false for HEIC', () {
      final bytes = Uint8List(20);
      bytes[4] = 0x66;
      bytes[5] = 0x74;
      bytes[6] = 0x79;
      bytes[7] = 0x70;
      bytes[8] = 0x68;
      bytes[9] = 0x65;
      bytes[10] = 0x69;
      bytes[11] = 0x63;
      expect(isValidImageFormat(bytes), false);
    });

    test('returns false for unknown format', () {
      expect(isValidImageFormat(Uint8List.fromList([0x00, 0x00, 0x00, 0x00])), false);
    });
  });

  group('prepareImageForUpload', () {
    test('throws for empty bytes', () {
      expect(
        prepareImageForUpload(Uint8List(0)),
        throwsA(isA<ImagePreparationException>()),
      );
    });

    test('accepts valid JPEG and returns PreparedImage', () async {
      final bytes = _minimalJpegBytes();
      final result = await prepareImageForUpload(bytes);
      expect(result.contentType, 'image/jpeg');
      expect(result.bytes, bytes);
    });

    test('throws for JPEG header without decodable image data', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF,
        ...List.filled(10, 0x00),
      ]);
      expect(
        prepareImageForUpload(bytes),
        throwsA(isA<ImagePreparationException>()),
      );
    });

    test('throws for unsupported format', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(
        prepareImageForUpload(bytes),
        throwsA(isA<ImagePreparationException>()),
      );
    });

    test('re-encodes JPEG when jpegQuality is set', () async {
      final bytes = _minimalJpegBytes();
      final result = await prepareImageForUpload(bytes, jpegQuality: 85);
      expect(result.contentType, 'image/jpeg');
      expect(result.bytes, isNot(equals(bytes)));
      expect(img.decodeImage(result.bytes), isNotNull);
    });

    test('keeps small PNG unchanged when no resize or quality requested', () async {
      final bytes = _minimalPngBytes();
      final result = await prepareImageForUpload(bytes);
      expect(result.contentType, 'image/png');
      expect(result.bytes, bytes);
    });

    test('resizes large images to maxDimension', () async {
      final large = img.Image(width: 3000, height: 1500);
      final bytes = Uint8List.fromList(img.encodeJpg(large, quality: 90));
      final result = await prepareImageForUpload(
        bytes,
        maxDimension: 2048,
        jpegQuality: 85,
      );
      final decoded = img.decodeImage(result.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      expect(decoded.height, 1024);
      expect(result.contentType, 'image/jpeg');
    });
  });

  group('readJpegDimensions', () {
    test('returns dimensions for valid JPEG bytes', () {
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 800, height: 600), quality: 90),
      );
      expect(readJpegDimensions(bytes), (800, 600));
    });

    test('returns null for non-JPEG bytes', () {
      expect(readJpegDimensions(_minimalPngBytes()), isNull);
    });
  });

  group('prepareImageForSpotPromotion fast path', () {
    test('returns original JPEG bytes when already within max dimension', () async {
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 1200, height: 900), quality: 90),
      );
      final result = await prepareImageForSpotPromotion(bytes, maxDimension: 2048);
      expect(result.bytes, bytes);
      expect(result.contentType, 'image/jpeg');
    });
  });

  group('resizeImageForSpotUpload', () {
    test('returns null for corrupt JPEG header', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF,
        ...List.filled(10, 0x00),
      ]);
      expect(resizeImageForSpotUpload(bytes), isNull);
    });

    test('resizes valid JPEG bytes', () {
      final large = img.Image(width: 4000, height: 2000);
      final bytes = Uint8List.fromList(img.encodeJpg(large, quality: 90));
      final resized = resizeImageForSpotUpload(bytes);
      expect(resized, isNotNull);
      final decoded = img.decodeImage(resized!);
      expect(decoded!.width, 2048);
    });
  });
}
