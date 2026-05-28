import 'package:flutter_test/flutter_test.dart';
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
}
