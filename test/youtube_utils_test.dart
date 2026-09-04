import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/youtube_utils.dart';

void main() {
  group('extractYoutubeVideoId', () {
    test('returns null for empty input', () {
      expect(extractYoutubeVideoId(''), isNull);
      expect(extractYoutubeVideoId('   '), isNull);
    });

    test('returns bare IDs as-is', () {
      expect(extractYoutubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('extracts from youtu.be URLs', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/abc123xyz01'),
        'abc123xyz01',
      );
    });

    test('extracts from watch URLs', () {
      expect(
        extractYoutubeVideoId(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts from embed and shorts URLs', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/embed/abc123xyz01'),
        'abc123xyz01',
      );
      expect(
        extractYoutubeVideoId('https://www.youtube.com/shorts/abc123xyz01'),
        'abc123xyz01',
      );
    });
  });

  group('youtubeIdsNeedingThumbnails', () {
    test('returns only newly added IDs', () {
      expect(
        youtubeIdsNeedingThumbnails(
          previousIds: const ['aaa'],
          nextIds: const ['aaa', 'bbb'],
        ),
        ['bbb'],
      );
    });

    test('skips IDs that already have a CDN thumbnail in photos', () {
      expect(
        youtubeIdsNeedingThumbnails(
          previousIds: const [],
          nextIds: const ['bbb'],
          existingImageUrls: const [
            'https://img.youtube.com/vi/bbb/maxresdefault.jpg',
          ],
        ),
        isEmpty,
      );
    });

    test('preserves first-seen order and drops duplicates', () {
      expect(
        youtubeIdsNeedingThumbnails(
          previousIds: const [],
          nextIds: const ['bbb', 'ccc', 'bbb'],
        ),
        ['bbb', 'ccc'],
      );
    });
  });

  group('appendYoutubeThumbnails', () {
    test('appends CDN URLs when no resolved Storage URLs are provided', () {
      expect(
        appendYoutubeThumbnails(
          imageUrls: const ['https://example.com/photo.jpg'],
          videoIds: const ['bbb'],
        ),
        [
          'https://example.com/photo.jpg',
          'https://img.youtube.com/vi/bbb/maxresdefault.jpg',
        ],
      );
    });

    test('prefers resolved Storage URLs', () {
      expect(
        appendYoutubeThumbnails(
          imageUrls: const [],
          videoIds: const ['bbb'],
          resolvedUrls: const {
            'bbb': 'https://storage.googleapis.com/bucket/spots/thumb.jpg',
          },
        ),
        ['https://storage.googleapis.com/bucket/spots/thumb.jpg'],
      );
    });

    test('does not duplicate an existing CDN thumbnail', () {
      expect(
        appendYoutubeThumbnails(
          imageUrls: const [
            'https://img.youtube.com/vi/bbb/maxresdefault.jpg',
          ],
          videoIds: const ['bbb'],
        ),
        ['https://img.youtube.com/vi/bbb/maxresdefault.jpg'],
      );
    });
  });
}
