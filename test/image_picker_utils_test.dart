import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:parkour_spot/utils/image_picker_utils.dart';

void main() {
  group('preparePickedImageBytes', () {
    test('validates decodable JPEG on all platforms', () async {
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 4, height: 4), quality: 90),
      );
      final prepared = await preparePickedImageBytes(bytes);
      expect(prepared.contentType, 'image/jpeg');
      expect(img.decodeImage(prepared.bytes), isNotNull);
    });
  });
}
