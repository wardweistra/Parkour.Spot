import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/event_report.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/widgets/location_review_map.dart';
import 'package:parkour_spot/widgets/event_suggested_edits_summary.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required EventReport report,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EventSuggestedEditsSummary(report: report),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  EventReport buildReport({
    bool suggestedLocationRemoved = false,
    List<String>? suggestedSpotIds,
    double? suggestedLatitude,
    double? suggestedLongitude,
  }) {
    return EventReport(
      id: 'report-1',
      title: 'Jam session',
      status: 'New',
      startAt: DateTime.utc(2026, 5, 28, 18),
      suggestedLocationRemoved: suggestedLocationRemoved,
      suggestedSpotIds: suggestedSpotIds,
      suggestedLatitude: suggestedLatitude,
      suggestedLongitude: suggestedLongitude,
    );
  }

  testWidgets('shows remove location chip and detail when location is removed', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(suggestedLocationRemoved: true),
    );

    expect(find.text('Remove location'), findsOneWidget);
    expect(find.text('Location: Remove location'), findsOneWidget);
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('shows linked spots count when spot linking changes', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(suggestedSpotIds: const <String>['spot-a', 'spot-b']),
    );

    expect(find.text('Linking'), findsOneWidget);
    expect(find.text('Linking: 2 linked spots'), findsOneWidget);
  });

  testWidgets('shows location chip when coordinates are suggested', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(
        suggestedLatitude: 52.12345,
        suggestedLongitude: 4.56789,
      ),
    );

    expect(find.text('Location'), findsOneWidget);
    expect(find.textContaining('52.12345, 4.56789'), findsOneWidget);
    expect(find.byType(LocationReviewMap), findsOneWidget);
    expect(find.byType(GoogleMap), findsOneWidget);
  });

  testWidgets('shows comparison map when current and suggested locations exist', (
    tester,
  ) async {
    final report = EventReport(
      id: 'report-1',
      title: 'Jam session',
      status: 'New',
      startAt: DateTime.utc(2026, 5, 28, 18),
      latitude: 52.1,
      longitude: 4.3,
      suggestedLatitude: 52.2,
      suggestedLongitude: 4.4,
      targetEventId: 'event-1',
    );

    await pumpSummary(tester, report: report);

    expect(find.byType(LocationReviewMap), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no suggested edits', (
    tester,
  ) async {
    await pumpSummary(tester, report: buildReport());

    expect(find.text('Suggested changes'), findsNothing);
  });
}
