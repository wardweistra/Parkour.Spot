import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/inbox_notification_open_uri.dart';

void main() {
  group('notificationIdFromUri', () {
    test('returns nid when present', () {
      expect(notificationIdFromUri(Uri.parse('/spot/abc?nid=n1')), 'n1');
    });

    test('returns null when missing or blank', () {
      expect(notificationIdFromUri(Uri.parse('/spot/abc')), isNull);
      expect(notificationIdFromUri(Uri.parse('/spot/abc?nid=')), isNull);
      expect(notificationIdFromUri(Uri.parse('/spot/abc?nid=%20')), isNull);
    });
  });

  group('uriWithoutNotificationId', () {
    test('removes nid and keeps other query params', () {
      final uri = Uri.parse('/spot/abc?nid=n1&imageIndex=2');
      expect(
        uriWithoutNotificationId(uri).toString(),
        '/spot/abc?imageIndex=2',
      );
    });

    test('clears query when nid was the only param', () {
      final stripped = uriWithoutNotificationId(Uri.parse('/spot/abc?nid=n1'));
      expect(stripped.path, '/spot/abc');
      expect(stripped.query, isEmpty);
    });

    test('leaves URIs without nid unchanged', () {
      final uri = Uri.parse('/spot/abc?imageIndex=2');
      expect(uriWithoutNotificationId(uri), same(uri));
    });
  });

  group('goLocationFromUri', () {
    test('returns path without nid', () {
      expect(goLocationFromUri(Uri.parse('/spot/abc?nid=n1')), '/spot/abc');
    });

    test('keeps remaining query params', () {
      expect(
        goLocationFromUri(Uri.parse('/event/e1?nid=n1&x=1')),
        '/event/e1?x=1',
      );
    });
  });
}
