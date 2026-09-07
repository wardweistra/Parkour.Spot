import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkour_spot/utils/image_url_utils.dart';
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

  group('getYoutubeThumbnailUrlCandidates', () {
    test('returns qualities highest-first for YouTube CDN URLs', () {
      expect(
        getYoutubeThumbnailUrlCandidates(
          'https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg',
        ),
        [
          'https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg',
          'https://img.youtube.com/vi/pjJ2XwoSmx8/sddefault.jpg',
          'https://img.youtube.com/vi/pjJ2XwoSmx8/hqdefault.jpg',
        ],
      );
    });

    test('returns an empty list for non-YouTube URLs', () {
      expect(
        getYoutubeThumbnailUrlCandidates('https://example.com/a.jpg'),
        isEmpty,
      );
    });
  });

  group('resolveYoutubeThumbnailUrl', () {
    test('skips unavailable qualities and returns the first HTTP 200', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/maxresdefault.jpg')) {
          return http.Response('', 404);
        }
        if (request.url.path.endsWith('/sddefault.jpg')) {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final resolved = await resolveYoutubeThumbnailUrl(
        'pjJ2XwoSmx8',
        client: client,
      );

      expect(
        resolved,
        'https://img.youtube.com/vi/pjJ2XwoSmx8/sddefault.jpg',
      );
    });

    test('returns null when no qualities are available', () async {
      final client = MockClient((request) async => http.Response('', 404));

      final resolved = await resolveYoutubeThumbnailUrl(
        'pjJ2XwoSmx8',
        client: client,
      );

      expect(resolved, isNull);
    });
  });

  group('getResizedImageUrlCandidates', () {
    test('uses YouTube fallback candidates for CDN thumbnail URLs', () {
      expect(
        getResizedImageUrlCandidates(
          'https://i3.ytimg.com/vi/pjJ2XwoSmx8/maxresdefault.jpg',
        ),
        [
          'https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg',
          'https://img.youtube.com/vi/pjJ2XwoSmx8/sddefault.jpg',
          'https://img.youtube.com/vi/pjJ2XwoSmx8/hqdefault.jpg',
        ],
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
