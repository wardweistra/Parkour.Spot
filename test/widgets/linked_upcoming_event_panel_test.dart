import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/utils/upcoming_linked_events_utils.dart';
import 'package:parkour_spot/widgets/linked_upcoming_event_panel.dart';

final _now = DateTime.utc(2026, 8, 19, 10);

UpcomingLinkedEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
  DateTime? endAt,
}) {
  return UpcomingLinkedEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: endAt,
  );
}

Future<void> pumpPanel(
  WidgetTester tester, {
  required LinkedSpotEvents events,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: LinkedUpcomingEventPanel(
            eventsFuture: Future<LinkedSpotEvents>.value(events),
            margin: EdgeInsets.zero,
            now: _now,
          ),
        ),
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) =>
            Text('event ${state.pathParameters['id']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows nothing when there are no linked events', (tester) async {
    await pumpPanel(tester, events: const LinkedSpotEvents());

    expect(find.text('Upcoming event'), findsNothing);
    expect(find.text('Past event'), findsNothing);
  });

  testWidgets('keeps a single upcoming event highlighted', (tester) async {
    await pumpPanel(
      tester,
      events: LinkedSpotEvents(
        upcoming: [
          _event(
            id: 'next',
            title: 'Autumn jam',
            startAt: DateTime.utc(2026, 9, 12, 12),
          ),
        ],
      ),
    );

    expect(find.text('Upcoming event'), findsOneWidget);
    expect(find.text('Autumn jam'), findsOneWidget);
    expect(find.text('Past event'), findsNothing);
    expect(find.text('1 more'), findsNothing);
  });

  testWidgets('shows a muted past callout when only history exists', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      events: LinkedSpotEvents(
        past: [
          _event(
            id: 'gathering',
            title: 'International Gathering',
            startAt: DateTime.utc(2026, 8, 2, 12),
            endAt: DateTime.utc(2026, 8, 8, 8),
          ),
        ],
      ),
    );

    expect(find.text('Past event'), findsOneWidget);
    expect(find.text('International Gathering'), findsOneWidget);
    expect(find.text('Upcoming event'), findsNothing);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets(
    'features the next upcoming event and offers past events as one action',
    (tester) async {
      await pumpPanel(
        tester,
        events: LinkedSpotEvents(
          upcoming: [
            _event(
              id: 'next',
              title: 'Autumn jam',
              startAt: DateTime.utc(2026, 9, 12, 12),
            ),
          ],
          past: [
            _event(
              id: 'gathering',
              title: 'International Gathering',
              startAt: DateTime.utc(2026, 8, 2, 12),
              endAt: DateTime.utc(2026, 8, 8, 8),
            ),
          ],
        ),
      );

      expect(find.text('Upcoming event'), findsOneWidget);
      expect(find.text('Autumn jam'), findsOneWidget);
      expect(find.text('Past event'), findsNothing);
      expect(find.text('International Gathering'), findsNothing);
      expect(find.text('1 past event'), findsOneWidget);
    },
  );

  testWidgets('uses X more when additional upcoming events remain', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      events: LinkedSpotEvents(
        upcoming: [
          _event(
            id: 'next',
            title: 'Autumn jam',
            startAt: DateTime.utc(2026, 9, 12, 12),
          ),
          _event(
            id: 'later',
            title: 'Winter jam',
            startAt: DateTime.utc(2026, 12, 1, 12),
          ),
        ],
        past: [
          _event(
            id: 'gathering',
            title: 'International Gathering',
            startAt: DateTime.utc(2026, 8, 2, 12),
            endAt: DateTime.utc(2026, 8, 8, 8),
          ),
        ],
      ),
    );

    expect(find.text('2 more'), findsOneWidget);
    expect(find.text('Winter jam'), findsNothing);
    expect(find.text('International Gathering'), findsNothing);
  });

  testWidgets('uses X more on a past callout with more history', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      events: LinkedSpotEvents(
        past: [
          _event(
            id: 'recent',
            title: 'Recent jam',
            startAt: DateTime.utc(2026, 8, 2),
            endAt: DateTime.utc(2026, 8, 3),
          ),
          _event(
            id: 'older',
            title: 'Older jam',
            startAt: DateTime.utc(2026, 6, 1),
            endAt: DateTime.utc(2026, 6, 2),
          ),
        ],
      ),
    );

    expect(find.text('Past event'), findsNothing);
    expect(find.text('Past events'), findsOneWidget);
    expect(find.text('Recent jam'), findsOneWidget);
    expect(find.text('1 more'), findsOneWidget);
    expect(find.text('Older jam'), findsNothing);
  });

  testWidgets('sheet lists all events future-to-past with status labels', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      events: LinkedSpotEvents(
        upcoming: [
          _event(
            id: 'happening',
            title: 'Live jam',
            startAt: DateTime.utc(2026, 8, 18),
            endAt: DateTime.utc(2026, 8, 20),
          ),
          _event(
            id: 'later',
            title: 'Winter jam',
            startAt: DateTime.utc(2026, 12, 1),
          ),
        ],
        past: [
          _event(
            id: 'gathering',
            title: 'International Gathering',
            startAt: DateTime.utc(2026, 8, 2),
            endAt: DateTime.utc(2026, 8, 8),
          ),
        ],
      ),
    );

    expect(find.text('Happening now'), findsOneWidget);
    expect(find.text('2 more'), findsOneWidget);
    await tester.tap(find.text('2 more'));
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Happening now'), findsNWidgets(2));
    expect(find.text('Past'), findsOneWidget);

    final tileTitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(tileTitles, ['Winter jam', 'Live jam', 'International Gathering']);
  });
}
