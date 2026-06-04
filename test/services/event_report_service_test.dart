import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_report.dart';
import 'package:parkour_spot/services/event_report_service.dart';

void main() {
  group('EventReportService.resolveEventCreatedBy', () {
    test('prefers reporter user id when present', () {
      final createdBy = EventReportService.resolveEventCreatedBy(
        reporterUserId: ' reporter-uid ',
        approverUserId: 'moderator-uid',
      );

      expect(createdBy, 'reporter-uid');
    });

    test('falls back to approver when reporter user id is missing', () {
      final createdBy = EventReportService.resolveEventCreatedBy(
        reporterUserId: '   ',
        approverUserId: 'moderator-uid',
      );

      expect(createdBy, 'moderator-uid');
    });
  });

  group('EventReportService.buildExistingEventSuggestionUpdateForTest', () {
    EventReport report({
      List<String>? suggestedSpotIds,
      double? suggestedLatitude,
      double? suggestedLongitude,
      String? suggestedAddress,
      String? suggestedCity,
      String? suggestedCountryCode,
      bool suggestedLocationRemoved = false,
    }) {
      return EventReport(
        id: 'report-1',
        title: 'Jam',
        status: 'New',
        startAt: DateTime.utc(2026, 5, 28, 18),
        suggestedSpotIds: suggestedSpotIds,
        suggestedLatitude: suggestedLatitude,
        suggestedLongitude: suggestedLongitude,
        suggestedAddress: suggestedAddress,
        suggestedCity: suggestedCity,
        suggestedCountryCode: suggestedCountryCode,
        suggestedLocationRemoved: suggestedLocationRemoved,
      );
    }

    test('updates linked spot ids when suggested', () {
      final updates =
          EventReportService.buildExistingEventSuggestionUpdateForTest(
            report: report(
              suggestedSpotIds: const <String>['spot-b', 'spot-a'],
            ),
            existingEventData: const <String, dynamic>{},
          );

      expect(updates, isNotNull);
      expect(updates!['spotIds'], <String>['spot-a', 'spot-b']);
    });

    test('updates venue coordinates and address when suggested', () {
      final updates =
          EventReportService.buildExistingEventSuggestionUpdateForTest(
            report: report(
              suggestedLatitude: 52.3728,
              suggestedLongitude: 4.8936,
              suggestedAddress: 'Dam Square, Amsterdam',
              suggestedCity: 'Amsterdam',
              suggestedCountryCode: 'nl',
            ),
            existingEventData: const <String, dynamic>{},
          );

      expect(updates, isNotNull);
      expect(updates!['latitude'], 52.3728);
      expect(updates['longitude'], 4.8936);
      expect(updates['address'], 'Dam Square, Amsterdam');
      expect(updates['city'], 'Amsterdam');
      expect(updates['countryCode'], 'NL');
    });

    test('deletes venue fields when location removal is suggested', () {
      final updates =
          EventReportService.buildExistingEventSuggestionUpdateForTest(
            report: report(suggestedLocationRemoved: true),
            existingEventData: const <String, dynamic>{},
          );

      expect(updates, isNotNull);
      expect(updates!['latitude'], isA<FieldValue>());
      expect(updates['longitude'], isA<FieldValue>());
      expect(updates['address'], isA<FieldValue>());
      expect(updates['city'], isA<FieldValue>());
      expect(updates['countryCode'], isA<FieldValue>());
    });
  });
}
