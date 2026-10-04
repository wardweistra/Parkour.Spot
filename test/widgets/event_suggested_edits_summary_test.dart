import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/event_report.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/widgets/event_suggested_edits_summary.dart';
import 'package:parkour_spot/widgets/location_review_map.dart';
import 'package:parkour_spot/widgets/location_suggestion_review.dart';
import 'package:parkour_spot/widgets/text_diff_view.dart';
import 'package:parkour_spot/widgets/value_before_after_view.dart';

void main() {
  Future<void> pumpSummary(
    WidgetTester tester, {
    required EventReport report,
    ParkourEvent? currentEvent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EventSuggestedEditsSummary(
            report: report,
            currentEvent: currentEvent,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  EventReport buildReport({
    bool suggestedLocationRemoved = false,
    List<String>? suggestedSpotIds,
    List<String>? suggestedSpotListIds,
    double? suggestedLatitude,
    double? suggestedLongitude,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return EventReport(
      id: 'report-1',
      title: 'Jam session',
      status: 'New',
      startAt: DateTime.utc(2026, 5, 28, 18),
      latitude: latitude,
      longitude: longitude,
      address: address,
      suggestedLocationRemoved: suggestedLocationRemoved,
      suggestedSpotIds: suggestedSpotIds,
      suggestedSpotListIds: suggestedSpotListIds,
      suggestedLatitude: suggestedLatitude,
      suggestedLongitude: suggestedLongitude,
    );
  }

  testWidgets(
    'shows remove location chip and location review when location is removed',
    (tester) async {
      await pumpSummary(
        tester,
        report: buildReport(
          suggestedLocationRemoved: true,
          latitude: 42.1,
          longitude: 24.5,
          address: 'Park street',
        ),
      );

      expect(find.text('Remove location'), findsWidgets);
      expect(find.byType(LocationSuggestionReview), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    },
  );

  testWidgets('shows linked spot ids while names are unavailable', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(suggestedSpotIds: const <String>['spot-a', 'spot-b']),
    );

    expect(find.text('Linking'), findsOneWidget);
    expect(find.byType(LocationSuggestionReview), findsOneWidget);
    expect(find.textContaining('spot-a'), findsOneWidget);
    expect(find.textContaining('spot-b'), findsOneWidget);
    expect(find.text('Linking: 2 linked spots'), findsNothing);
  });

  testWidgets('spots suggestion does not also show location removal chip', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(
        suggestedSpotIds: const <String>['spot-a'],
        suggestedLocationRemoved: true,
        suggestedSpotListIds: const <String>[],
      ),
    );

    expect(find.text('Linking'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Remove location'), findsNothing);
    expect(find.widgetWithText(Chip, 'Location'), findsNothing);
    expect(find.text('Add spot list'), findsNothing);
  });

  testWidgets('list suggestion describes lists instead of a pin mix', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      report: buildReport(
        suggestedSpotListIds: const <String>['list-1'],
        suggestedSpotIds: const <String>[],
        suggestedLocationRemoved: true,
      ),
    );

    expect(find.text('Add spot list'), findsOneWidget);
    expect(find.textContaining('list-1'), findsOneWidget);
    expect(find.text('Linking'), findsNothing);
    expect(find.widgetWithText(Chip, 'Remove location'), findsNothing);
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

    expect(find.widgetWithText(Chip, 'Location'), findsOneWidget);
    expect(find.byType(LocationSuggestionReview), findsOneWidget);
    expect(find.byType(LocationReviewMap), findsOneWidget);
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.byType(ValueBeforeAfterView), findsOneWidget);
    expect(find.textContaining('52.12345, 4.56789'), findsOneWidget);
  });

  testWidgets(
    'shows comparison map when current and suggested locations exist',
    (tester) async {
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
      expect(find.text('Current'), findsNWidgets(2));
      expect(find.text('Suggested'), findsNWidgets(2));
    },
  );

  testWidgets('renders nothing when there are no suggested edits', (
    tester,
  ) async {
    await pumpSummary(tester, report: buildReport());

    expect(find.text('Suggested changes'), findsNothing);
  });

  testWidgets(
    'shows unified diffs against the current event when provided',
    (tester) async {
      final report = EventReport(
        id: 'report-1',
        title: 'Jam session',
        status: 'New',
        startAt: DateTime.utc(2026, 5, 28, 18),
        suggestedTitle: 'Evening jam',
        suggestedDescription: 'Bring shoes',
        targetEventId: 'event-1',
      );
      final currentEvent = ParkourEvent(
        id: 'event-1',
        title: 'Jam session',
        description: 'Casual training',
        startAt: DateTime.utc(2026, 5, 28, 18),
      );

      await pumpSummary(
        tester,
        report: report,
        currentEvent: currentEvent,
      );

      expect(find.byType(TextDiffView), findsNWidgets(2));
      expect(find.byType(ValueBeforeAfterView), findsNothing);
      expect(find.textContaining('Jam session'), findsWidgets);
      expect(find.textContaining('Evening jam'), findsOneWidget);
      expect(find.textContaining('Casual training'), findsOneWidget);
      expect(find.textContaining('Bring shoes'), findsOneWidget);
      expect(find.text('Title: Evening jam'), findsNothing);
    },
  );

  testWidgets('location review shows linked spot names in the summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocationSuggestionReview(
            current: LocationSuggestionSide.pin(
              latitude: 42.13845,
              longitude: 24.53547,
              address: 'Parkour Park, Stamboliyski',
              city: 'Stamboliyski',
              countryCode: 'BG',
            ),
            suggested: LocationSuggestionSide.linkedSpots(
              spotIds: const <String>['spot-1'],
              spotsById: <String, Spot>{
                'spot-1': Spot(
                  id: 'spot-1',
                  name: 'Parkour Park Stamboliyski',
                  description: '',
                  latitude: 42.14,
                  longitude: 24.54,
                ),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parkour Park Stamboliyski'), findsOneWidget);
    expect(find.textContaining('42.13845'), findsOneWidget);
    expect(find.byType(LocationReviewMap), findsOneWidget);
    expect(find.byType(ValueBeforeAfterView), findsOneWidget);
    expect(find.text('Current'), findsNWidgets(2));
    expect(find.text('Suggested'), findsNWidgets(2));
  });

  testWidgets('uses before/after for non-text event fields', (tester) async {
    final report = EventReport(
      id: 'report-1',
      title: 'Jam session',
      status: 'New',
      startAt: DateTime.utc(2026, 5, 28, 18),
      suggestedWebsiteUrl: 'https://example.com/new',
      targetEventId: 'event-1',
    );
    final currentEvent = ParkourEvent(
      id: 'event-1',
      title: 'Jam session',
      websiteUrl: 'https://example.com/old',
      startAt: DateTime.utc(2026, 5, 28, 18),
    );

    await pumpSummary(
      tester,
      report: report,
      currentEvent: currentEvent,
    );

    expect(find.byType(TextDiffView), findsNothing);
    expect(find.byType(ValueBeforeAfterView), findsOneWidget);
    expect(find.text('https://example.com/old'), findsOneWidget);
    expect(find.text('https://example.com/new'), findsOneWidget);
  });
}
