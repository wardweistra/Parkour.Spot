import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/community_activity.dart';
import 'package:parkour_spot/models/community_activity_lens.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/widgets/community_activity_kind_filter.dart';
import 'package:parkour_spot/widgets/community_activity_stream.dart';

final DateTime _now = DateTime.utc(2026, 11, 1, 12);

CommunityActivityItem _item(String id, CommunityActivityKind kind) {
  return CommunityActivityItem(
    id: id,
    kind: kind,
    latitude: 52.37,
    longitude: 4.9,
    occurredAt: _now.subtract(const Duration(hours: 2)),
    startAt: kind == CommunityActivityKind.spotTrainingPlan
        ? _now.add(const Duration(hours: 1))
        : null,
    endAt: kind == CommunityActivityKind.spotTrainingPlan
        ? _now.add(const Duration(hours: 3))
        : null,
    spotId: 'spot-$id',
    spotName: 'Spot $id',
    actorDisplayName: 'Alex',
    actorUserId: 'u1',
  );
}

CommunityEventItem _event(String id, {bool isPast = false}) {
  final start = isPast
      ? _now.subtract(const Duration(days: 2))
      : _now.add(const Duration(days: 1));
  return CommunityEventItem(
    pin: EventMapPin(
      id: 'pin-$id',
      eventId: id,
      kind: EventMapPinKind.venue,
      latitude: 52.37,
      longitude: 4.9,
      title: 'Jam $id',
      startAt: start,
      endAt: start.add(const Duration(hours: 3)),
    ),
    goingCount: 2,
    isPast: isPast,
  );
}

CommunityActivityFeed _mixedFeed() {
  return CommunityActivityFeed(
    past: [
      _item('added', CommunityActivityKind.spotAdded),
      _item('checkin', CommunityActivityKind.spotCheckIn),
    ],
    pastEvents: [_event('past-e', isPast: true)],
    upcoming: [_item('plan', CommunityActivityKind.spotTrainingPlan)],
    events: [_event('up-e')],
  );
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required CommunityActivityLens lens,
  required ValueChanged<CommunityActivityLens> onChanged,
  CommunityActivityFeed? feed,
}) async {
  final source = feed ?? _mixedFeed();
  final filtered = filterCommunityActivityFeed(source, lens);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: filtered.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CommunityActivityKindFilter(
                      value: lens,
                      onChanged: onChanged,
                    ),
                    const Text('lens-empty'),
                  ],
                ),
              )
            : CommunityActivityStream(
                feed: filtered,
                now: _now,
                lens: lens,
                onLensChanged: onChanged,
                onOpenSpot: (_) {},
                onOpenEvent: (_) {},
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openLensMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(CommunityActivityKindFilter.buttonKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to All with icon-only filter on the now row', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.all,
      onChanged: (_) {},
    );

    expect(find.byKey(CommunityActivityKindFilter.buttonKey), findsOneWidget);
    expect(find.byType(CommunityNowDivider), findsOneWidget);
    // Closed control on All does not shout the "All" label.
    expect(find.text('All'), findsNothing);
    expect(find.textContaining('checked in'), findsOneWidget);
    expect(find.textContaining('added this new spot'), findsOneWidget);
    expect(find.textContaining('planning a session'), findsOneWidget);
    expect(find.text('Jam past-e'), findsOneWidget);
    expect(find.text('Jam up-e'), findsOneWidget);
  });

  testWidgets('active lens name shows on the closed control', (tester) async {
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.sessions,
      onChanged: (_) {},
    );

    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets('Events lens hides sessions and contributions via popup', (
    tester,
  ) async {
    var lens = CommunityActivityLens.all;

    await _pumpHarness(
      tester,
      lens: lens,
      onChanged: (next) => lens = next,
    );

    await _openLensMenu(tester);
    await tester.tap(find.byKey(CommunityActivityKindFilter.chipKeyEvents));
    await tester.pumpAndSettle();
    expect(lens, CommunityActivityLens.events);

    // Re-pump with updated lens (parent would setState).
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.events,
      onChanged: (_) {},
    );

    expect(find.text('Events'), findsOneWidget);
    expect(find.textContaining('checked in'), findsNothing);
    expect(find.textContaining('added this new spot'), findsNothing);
    expect(find.textContaining('planning a session'), findsNothing);
    expect(find.text('Jam past-e'), findsOneWidget);
    expect(find.text('Jam up-e'), findsOneWidget);
  });

  testWidgets('Sessions lens keeps check-ins and plans only', (tester) async {
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.sessions,
      onChanged: (_) {},
    );

    expect(find.textContaining('checked in'), findsOneWidget);
    expect(find.textContaining('planning a session'), findsOneWidget);
    expect(find.textContaining('added this new spot'), findsNothing);
    expect(find.text('Jam past-e'), findsNothing);
    expect(find.text('Jam up-e'), findsNothing);
  });

  testWidgets('Contributions lens keeps spot adds only in this feed', (
    tester,
  ) async {
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.contributions,
      onChanged: (_) {},
    );

    expect(find.text('Contributions'), findsOneWidget);
    expect(find.textContaining('added this new spot'), findsOneWidget);
    expect(find.textContaining('checked in'), findsNothing);
    expect(find.text('Jam past-e'), findsNothing);
  });

  testWidgets('empty lens shows empty placeholder with filter escape', (
    tester,
  ) async {
    final sessionsOnly = CommunityActivityFeed(
      past: [_item('checkin', CommunityActivityKind.spotCheckIn)],
    );

    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.events,
      onChanged: (_) {},
      feed: sessionsOnly,
    );

    expect(find.text('lens-empty'), findsOneWidget);
    expect(find.byKey(CommunityActivityKindFilter.buttonKey), findsOneWidget);
    expect(find.byType(CommunityActivityStream), findsNothing);
  });

  testWidgets('selecting All restores full list from Events', (tester) async {
    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.events,
      onChanged: (_) {},
    );
    expect(find.textContaining('checked in'), findsNothing);

    await _pumpHarness(
      tester,
      lens: CommunityActivityLens.all,
      onChanged: (_) {},
    );
    expect(find.textContaining('checked in'), findsOneWidget);
    expect(find.text('Jam past-e'), findsOneWidget);
  });
}
