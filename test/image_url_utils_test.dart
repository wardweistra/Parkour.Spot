import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/image_url_utils.dart';

void main() {
  group('getResizedImageUrl', () {
    test('returns original for non-Firebase URLs', () {
      const url = 'https://example.com/image.jpg';
      expect(getResizedImageUrl(url), url);
    });

    test('converts firebasestorage spots URL to resized (encoded path)', () {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fphoto.jpg';
      final result = getResizedImageUrl(url);
      expect(result, contains('spots%2Fresized%2Fphoto_1200x630.webp'));
    });

    test('converts firebasestorage URL with query params (regression: decoded pathSegments)', () {
      // Real-world URL format from getDownloadURL() - the bug was that
      // Uri.pathSegments returns decoded segments (spots/filename.jpg)
      // but the URL contains encoded form (spots%2Ffilename.jpg), so
      // indexOf failed and the replacement never ran.
      const url =
          'https://firebasestorage.googleapis.com/v0/b/parkourspot-93c90.firebasestorage.app/o/spots%2F1755763336408_web_image.jpg?alt=media&token=7ca703bc-2807-43c5-9a2d-3ea1d94c5f95';
      final result = getResizedImageUrl(url);
      expect(result, contains('spots%2Fresized%2F1755763336408_web_image_1200x630.webp'));
      expect(result, contains('?alt=media&token='));
    });

    test('converts storage.googleapis spots URL to resized', () {
      const url = 'https://storage.googleapis.com/bucket/spots/photo.png';
      final result = getResizedImageUrl(url);
      expect(result, contains('/spots/resized/photo_1200x630.webp'));
    });

    test('returns original if already resized', () {
      const url =
          'https://storage.googleapis.com/bucket/spots/resized/photo_1200x630.webp';
      expect(getResizedImageUrl(url), url);
    });
  });

  group('getResizedPathInfo', () {
    test('returns info for firebasestorage spots URL', () {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fphoto.jpg';
      final info = getResizedPathInfo(url);
      expect(info, isNotNull);
      expect(info!.originalPath, 'spots/photo.jpg');
      expect(info.resizedPath, 'spots/resized/photo_1200x630.webp');
    });

    test('returns null for non-Firebase URLs', () {
      expect(getResizedPathInfo('https://example.com/image.jpg'), isNull);
    });

    test('returns null for already resized paths', () {
      const url =
          'https://storage.googleapis.com/bucket/spots/resized/photo_1200x630.webp';
      expect(getResizedPathInfo(url), isNull);
    });
  });
}
