import 'package:flutter/material.dart';
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

  group('EventScheduleUtils.formatSummaryLine year', () {
    final now = DateTime.utc(2026, 8, 19, 10);

    Future<String> summary(
      WidgetTester tester, {
      required DateTime startAt,
      DateTime? endAt,
      bool isDateOnly = true,
      String? timeZone = 'UTC',
    }) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              result = EventScheduleUtils.formatSummaryLine(
                context,
                startAt: startAt,
                endAt: endAt,
                isDateOnly: isDateOnly,
                timeZone: timeZone,
                now: now,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('omits the year when the event is in the current year', (
      tester,
    ) async {
      final text = await summary(
        tester,
        startAt: DateTime.utc(2026, 8, 2),
        endAt: DateTime.utc(2026, 8, 8),
      );
      expect(text, isNot(contains('2026')));
      expect(text, contains('Aug'));
    });

    testWidgets('adds the year when the event is in a different year', (
      tester,
    ) async {
      final past = await summary(
        tester,
        startAt: DateTime.utc(2025, 8, 2),
        endAt: DateTime.utc(2025, 8, 8),
      );
      expect(past, contains('2025'));

      final future = await summary(tester, startAt: DateTime.utc(2027, 9, 12));
      expect(future, contains('2027'));
      expect(future, isNot(contains('2026')));
    });

    testWidgets('adds the year only on dates outside the current year', (
      tester,
    ) async {
      final text = await summary(
        tester,
        startAt: DateTime.utc(2026, 12, 31),
        endAt: DateTime.utc(2027, 1, 2),
      );
      expect(text, isNot(contains('2026')));
      expect(text, contains('2027'));
    });
  });
}
