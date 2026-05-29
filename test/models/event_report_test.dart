import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_report.dart';

void main() {
  group('EventReport.hasSuggestedEdits', () {
    EventReport buildReport({
      DateTime? suggestedStartAt,
      DateTime? suggestedEndAt,
      bool? suggestedIsDateOnly,
      String? suggestedTimeZone,
    }) {
      return EventReport(
        id: 'report-1',
        title: 'Jam session',
        status: 'New',
        startAt: DateTime.utc(2026, 5, 28, 18),
        suggestedIsDateOnly: suggestedIsDateOnly,
        suggestedTimeZone: suggestedTimeZone,
        suggestedStartAt: suggestedStartAt,
        suggestedEndAt: suggestedEndAt,
      );
    }

    test('returns true when suggested start datetime exists', () {
      final report = buildReport(
        suggestedStartAt: DateTime.utc(2026, 5, 28, 19),
      );

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns true when suggested end datetime exists', () {
      final report = buildReport(suggestedEndAt: DateTime.utc(2026, 5, 28, 20));

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns true when suggested all-day value exists', () {
      final report = buildReport(suggestedIsDateOnly: true);

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns true when suggested timezone exists', () {
      final report = buildReport(suggestedTimeZone: 'Europe/Amsterdam');

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns false when no suggested fields are set', () {
      final report = buildReport();

      expect(report.hasSuggestedEdits, isFalse);
    });
  });
}
