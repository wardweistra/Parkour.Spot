import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/user_calendar_feed_service.dart';

void main() {
  const feed = 'https://parkour.spot/calendar/psc_abc.ics';

  group('UserCalendarFeedService.toWebcalUrl', () {
    test('converts https to webcal', () {
      expect(
        UserCalendarFeedService.toWebcalUrl(feed),
        'webcal://parkour.spot/calendar/psc_abc.ics',
      );
    });

    test('leaves webcal unchanged', () {
      const url = 'webcal://parkour.spot/calendar/psc_abc.ics';
      expect(UserCalendarFeedService.toWebcalUrl(url), url);
    });
  });

  group('UserCalendarFeedService.toGoogleCalendarSubscribeUrl', () {
    test('builds Google Calendar cid deep link with webcal feed', () {
      final url = UserCalendarFeedService.toGoogleCalendarSubscribeUrl(feed);
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/calendar/render');
      expect(
        uri.queryParameters['cid'],
        'webcal://parkour.spot/calendar/psc_abc.ics',
      );
    });
  });

  group('UserCalendarFeedService.toOutlookCalendarSubscribeUrl', () {
    test('builds Outlook addfromweb deep link', () {
      final url = UserCalendarFeedService.toOutlookCalendarSubscribeUrl(feed);
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'outlook.live.com');
      expect(uri.path, '/calendar/0/addfromweb');
      expect(uri.queryParameters['url'], feed);
      expect(
        uri.queryParameters['name'],
        UserCalendarFeedService.defaultCalendarDisplayName,
      );
    });
  });
}
