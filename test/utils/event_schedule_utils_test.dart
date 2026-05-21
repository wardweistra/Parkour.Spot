import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/event_schedule_utils.dart';

void main() {
  group('EventScheduleUtils', () {
    test('normalizes known timezone ids', () {
      expect(
        EventScheduleUtils.normalizeTimeZone('Europe/Paris'),
        'Europe/Paris',
      );
      expect(EventScheduleUtils.normalizeTimeZone('Invalid/Zone'), isNull);
      expect(EventScheduleUtils.normalizeTimeZone('  '), isNull);
    });

    test('converts local timezone date-time to UTC and back', () {
      final utc = EventScheduleUtils.localDateTimeToUtc(
        DateTime(2026, 7, 10, 18, 30),
        timeZone: 'Europe/Paris',
      );
      final display = EventScheduleUtils.toDisplayDateTime(
        utc,
        timeZone: 'Europe/Paris',
      );
      expect(display.year, 2026);
      expect(display.month, 7);
      expect(display.day, 10);
      expect(display.hour, 18);
      expect(display.minute, 30);
    });

    test('date start/end helpers create same-day boundaries', () {
      final startUtc = EventScheduleUtils.dateStartToUtc(
        DateTime(2026, 8, 2),
        timeZone: 'America/New_York',
      );
      final endUtc = EventScheduleUtils.dateEndToUtc(
        DateTime(2026, 8, 2),
        timeZone: 'America/New_York',
      );
      final startDisplay = EventScheduleUtils.toDisplayDateTime(
        startUtc,
        timeZone: 'America/New_York',
      );
      final endDisplay = EventScheduleUtils.toDisplayDateTime(
        endUtc,
        timeZone: 'America/New_York',
      );
      expect(startDisplay.hour, 0);
      expect(startDisplay.minute, 0);
      expect(endDisplay.hour, 23);
      expect(endDisplay.minute, 59);
      expect(
        EventScheduleUtils.isSameCalendarDay(
          startUtc,
          endUtc,
          timeZone: 'America/New_York',
        ),
        isTrue,
      );
    });
  });
}
