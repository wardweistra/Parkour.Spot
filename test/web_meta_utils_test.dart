import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/meta_clip.dart';

void main() {
  group('clipForMetaImpl', () {
    test('returns original when within limit', () {
      const text = 'Short description';
      expect(clipForMetaImpl(text), text);
    });

    test('returns original when exactly at limit', () {
      final text = 'A' * 280;
      expect(clipForMetaImpl(text), text);
    });

    test('clips at word boundary when last space is after 70% threshold', () {
      // maxLength=280, 70% = 196. If lastSpace is at 200, use it.
      final text = '${'word ' * 60}extra'; // ~305 chars
      final result = clipForMetaImpl(text, maxLength: 280);
      expect(result.endsWith('…'), true);
      expect(result.length, lessThanOrEqualTo(280));
    });

    test('clips at maxLength-1 when no suitable word boundary', () {
      final text = 'A' * 300; // No spaces
      final result = clipForMetaImpl(text, maxLength: 280);
      expect(result.endsWith('…'), true);
      expect(result.length, lessThanOrEqualTo(280));
    });

    test('honors custom maxLength', () {
      final text = 'A' * 100;
      final result = clipForMetaImpl(text, maxLength: 50);
      expect(result.endsWith('…'), true);
      expect(result.length, lessThanOrEqualTo(50));
    });

    test('trims trailing space before ellipsis', () {
      final text = '${'word ' * 60}x'; // ~301 chars, last word boundary before 70%
      final result = clipForMetaImpl(text, maxLength: 100);
      expect(result.endsWith('…'), true);
      expect(result.endsWith(' …'), false);
    });
  });
}
