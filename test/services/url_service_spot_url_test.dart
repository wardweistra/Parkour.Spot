import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/url_service.dart';

void main() {
  group('UrlService.generateNavigationUrl', () {
    test('uses country/city slug path for latin city names', () {
      expect(
        UrlService.generateNavigationUrl(
          'abc123',
          countryCode: 'NL',
          city: 'Amsterdam',
        ),
        '/nl/amsterdam/abc123',
      );
    });

    test('transliterates greek city names instead of empty city segment', () {
      expect(
        UrlService.generateNavigationUrl(
          '991hF1AL1pEGkWQDjB8S',
          countryCode: 'GR',
          city: 'Ηράκλειο',
        ),
        '/gr/irakleio/991hF1AL1pEGkWQDjB8S',
      );
    });

    test('falls back to /spot/:id when city is missing', () {
      expect(
        UrlService.generateNavigationUrl(
          'abc123',
          countryCode: 'GR',
          city: null,
        ),
        '/spot/abc123',
      );
      expect(
        UrlService.generateNavigationUrl(
          'abc123',
          countryCode: 'GR',
          city: '   ',
        ),
        '/spot/abc123',
      );
    });

    test('falls back to /spot/:id when city slugifies to empty', () {
      // Cyrillic is not transliterated yet — must not produce /ru//{id}.
      expect(
        UrlService.generateNavigationUrl(
          'abc123',
          countryCode: 'RU',
          city: 'Москва',
        ),
        '/spot/abc123',
      );
    });
  });

  group('UrlService.generateSpotUrl', () {
    test('prefixes the absolute origin', () {
      expect(
        UrlService.generateSpotUrl(
          '991hF1AL1pEGkWQDjB8S',
          countryCode: 'GR',
          city: 'Ηράκλειο',
        ),
        'https://parkour.spot/gr/irakleio/991hF1AL1pEGkWQDjB8S',
      );
    });
  });
}
