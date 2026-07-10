import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_report.dart';

void main() {
  group('EventReport.hasSuggestedEdits', () {
    EventReport buildReport({
      DateTime? suggestedStartAt,
      DateTime? suggestedEndAt,
      bool? suggestedIsDateOnly,
      String? suggestedTimeZone,
      List<String>? suggestedSpotIds,
      double? suggestedLatitude,
      double? suggestedLongitude,
      bool suggestedLocationRemoved = false,
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
        suggestedSpotIds: suggestedSpotIds,
        suggestedLatitude: suggestedLatitude,
        suggestedLongitude: suggestedLongitude,
        suggestedLocationRemoved: suggestedLocationRemoved,
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

    test('returns true when suggested linked spots are set', () {
      final report = buildReport(suggestedSpotIds: const <String>[]);

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns true when suggested venue location is set', () {
      final report = buildReport(
        suggestedLatitude: 52.1,
        suggestedLongitude: 4.3,
      );

      expect(report.hasSuggestedEdits, isTrue);
    });

    test('returns true when suggested venue location is removed', () {
      final report = buildReport(suggestedLocationRemoved: true);

      expect(report.hasSuggestedEdits, isTrue);
    });
  });

  group('EventReport.isDuplicateSuggestion', () {
    test('returns true when duplicateOfEventId is set', () {
      final report = EventReport(
        id: 'report-dup',
        title: 'Jam',
        status: 'New',
        startAt: DateTime.utc(2026, 5, 28, 18),
        targetEventId: 'event-a',
        duplicateOfEventId: 'event-b',
      );

      expect(report.isDuplicateSuggestion, isTrue);
    });

    test('returns false when duplicateOfEventId is empty', () {
      final report = EventReport(
        id: 'report-edit',
        title: 'Jam',
        status: 'New',
        startAt: DateTime.utc(2026, 5, 28, 18),
        targetEventId: 'event-a',
        suggestedTitle: 'New title',
      );

      expect(report.isDuplicateSuggestion, isFalse);
    });
  });
}
