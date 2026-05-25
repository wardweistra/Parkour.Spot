import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/browser_timezone_utils.dart';

void main() {
  group('BrowserTimezoneUtils', () {
    test('resolveDetectedTimeZone normalizes known ids', () {
      expect(
        resolveDetectedTimeZone('Europe/Paris'),
        'Europe/Paris',
      );
      expect(
        resolveDetectedTimeZone('  America/New_York  '),
        'America/New_York',
      );
    });

    test('resolveDetectedTimeZone falls back for invalid ids', () {
      expect(resolveDetectedTimeZone('Invalid/Zone'), 'UTC');
      expect(resolveDetectedTimeZone(null), 'UTC');
      expect(resolveDetectedTimeZone(''), 'UTC');
      expect(
        resolveDetectedTimeZone('Invalid/Zone', fallback: 'Europe/London'),
        'Europe/London',
      );
    });

    test('detectIanaTimeZone returns fallback when not on web', () {
      if (kIsWeb) return;
      expect(detectIanaTimeZone(), 'UTC');
      expect(detectIanaTimeZone(fallback: 'Europe/Berlin'), 'Europe/Berlin');
    });
  });
}
