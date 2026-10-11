import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/user_calendar_feed_service.dart';

void main() {
  group('UserCalendarFeedService.toWebcalUrl', () {
    test('converts https to webcal', () {
      expect(
        UserCalendarFeedService.toWebcalUrl(
          'https://parkour.spot/calendar/psc_abc.ics',
        ),
        'webcal://parkour.spot/calendar/psc_abc.ics',
      );
    });

    test('leaves webcal unchanged', () {
      const url = 'webcal://parkour.spot/calendar/psc_abc.ics';
      expect(UserCalendarFeedService.toWebcalUrl(url), url);
    });
  });
}
