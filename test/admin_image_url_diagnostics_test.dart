import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/admin_image_url_diagnostics.dart';

void main() {
  group('AdminImageUrlDiagnostic.fromUrl', () {
    test('derives resized and API URLs for firebasestorage spots URL', () {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fphoto.jpg?alt=media&token=abc';
      final d = AdminImageUrlDiagnostic.fromUrl(index: 1, originalUrl: url);

      expect(d.originalUrl, url);
      expect(d.isResizable, isTrue);
      expect(d.pathInfo!.originalPath, 'spots/photo.jpg');
      expect(d.expected1200x1200Url, contains('photo_1200x1200.webp'));
      expect(d.expected1200x630Url, contains('photo_1200x630.webp'));
      expect(d.spotsApiUrl, d.expected1200x1200Url);
    });

    test('marks non-resizable URLs without expected resized URLs', () {
      const url = 'https://example.com/image.jpg';
      final d = AdminImageUrlDiagnostic.fromUrl(index: 1, originalUrl: url);

      expect(d.isResizable, isFalse);
      expect(d.expected1200x1200Url, isNull);
      expect(d.expected1200x630Url, isNull);
      expect(d.spotsApiUrl, url);
    });
  });
}
