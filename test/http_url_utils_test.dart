import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/http_url_utils.dart';

void main() {
  group('normalizeHttpOrHttpsUrl', () {
    test('returns null for empty or whitespace-only input', () {
      expect(normalizeHttpOrHttpsUrl(''), isNull);
      expect(normalizeHttpOrHttpsUrl('   '), isNull);
    });

    test('prepends https when scheme is omitted', () {
      final out = normalizeHttpOrHttpsUrl('example.com/path');
      expect(out, isNotNull);
      expect(out, startsWith('https://'));
      expect(out, contains('example.com'));
    });

    test('accepts explicit http and https URLs', () {
      expect(
        normalizeHttpOrHttpsUrl('https://example.com/'),
        isNotNull,
      );
      expect(
        normalizeHttpOrHttpsUrl('http://example.com/foo?x=1'),
        isNotNull,
      );
    });

    test('normalizes scheme casing for validators', () {
      final out = normalizeHttpOrHttpsUrl('HTTPS://Example.COM/a');
      expect(out, isNotNull);
      expect(out!.toLowerCase(), startsWith('https://'));
    });

    test('returns null for clearly invalid input', () {
      expect(normalizeHttpOrHttpsUrl('not a url'), isNull);
      expect(normalizeHttpOrHttpsUrl('ftp://example.com'), isNull);
    });
  });

  group('isValidHttpOrHttpsUrl', () {
    test('matches normalizeHttpOrHttpsUrl non-null', () {
      expect(isValidHttpOrHttpsUrl('https://example.com'), isTrue);
      expect(isValidHttpOrHttpsUrl(''), isFalse);
      expect(isValidHttpOrHttpsUrl('bad'), isFalse);
    });
  });

  group('displayHttpUrlHost', () {
    test('returns host for standard https URL', () {
      expect(
        displayHttpUrlHost('https://example.com/path'),
        'example.com',
      );
    });

    test('includes non-default port', () {
      expect(
        displayHttpUrlHost('https://example.com:8080/'),
        'example.com:8080',
      );
    });

    test('omits default https port', () {
      expect(
        displayHttpUrlHost('https://example.com:443/foo'),
        'example.com',
      );
    });

    test('brackets IPv6 host for display', () {
      expect(
        displayHttpUrlHost('http://[::1]:8080/'),
        '[::1]:8080',
      );
    });

    test('falls back to full string when parse fails', () {
      expect(displayHttpUrlHost(':::'), ':::');
    });
  });
}
