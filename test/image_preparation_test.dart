import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/image_preparation.dart';

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
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF,
        ...List.filled(10, 0x00),
      ]);
      final result = await prepareImageForUpload(bytes);
      expect(result.contentType, 'image/jpeg');
      expect(result.bytes, bytes);
    });

    test('throws for unsupported format', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(
        prepareImageForUpload(bytes),
        throwsA(isA<ImagePreparationException>()),
      );
    });
  });
}
