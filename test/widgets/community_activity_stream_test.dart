import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/community_activity.dart';
import 'package:parkour_spot/models/event_map_pin.dart';
import 'package:parkour_spot/widgets/community_activity_stream.dart';

final DateTime _now = DateTime.utc(2026, 11, 1, 12);

CommunityActivityItem _item(
  String id,
  CommunityActivityKind kind, {
  required DateTime occurredAt,
  DateTime? startAt,
  DateTime? endAt,
  String actor = 'Alex',
  String? actorUserId = 'u1',
  int? photoCount,
}) {
  return CommunityActivityItem(
    id: id,
    kind: kind,
    latitude: 52.37,
    longitude: 4.9,
    occurredAt: occurredAt,
    startAt: startAt,
    endAt: endAt,
    spotId: 'spot-$id',
    spotName: 'Spot $id',
    city: 'Amsterdam',
    actorUserId: actorUserId,
    actorDisplayName: actor,
    photoCount: photoCount,
  );
}

CommunityEventItem _event(String id, DateTime startAt, {int going = 0}) {
  return CommunityEventItem(
    pin: EventMapPin(
      id: 'pin-$id',
      eventId: id,
      kind: EventMapPinKind.venue,
      latitude: 52.37,
      longitude: 4.9,
      title: 'Jam $id',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 3)),
    ),
    goingCount: going,
  );
}

Future<void> _pump(
  WidgetTester tester,
  CommunityActivityFeed feed, {
  ValueChanged<CommunityActivityItem>? onOpenSpot,
  ValueChanged<EventMapPin>? onOpenEvent,
  ValueChanged<String>? onOpenActor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CommunityActivityStream(
          feed: feed,
          now: _now,
          onOpenSpot: onOpenSpot ?? (_) {},
          onOpenEvent: onOpenEvent ?? (_) {},
          onOpenActor: onOpenActor,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _topOf(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder).dy;

void main() {
  testWidgets('renders past → now → upcoming with the expected copy', (
    tester,
  ) async {
    final feed = CommunityActivityFeed(
      past: [
        _item(
          'checkin',
          CommunityActivityKind.spotCheckIn,
          occurredAt: _now.subtract(const Duration(minutes: 5)),
          endAt: _now.add(const Duration(hours: 1)),
          actor: 'Zoë',
        ),
        _item(
          'photo',
          CommunityActivityKind.spotPhotoAdded,
          occurredAt: _now.subtract(const Duration(hours: 2)),
          actor: 'Yara',
          photoCount: 2,
        ),
        _item(
          'spot',
          CommunityActivityKind.spotAdded,
          occurredAt: _now.subtract(const Duration(days: 1)),
          actor: 'Xavi',
        ),
      ],
      upcoming: [
        _item(
          'plan',
          CommunityActivityKind.spotTrainingPlan,
          occurredAt: _now,
          startAt: _now.add(const Duration(hours: 3)),
          endAt: _now.add(const Duration(hours: 5)),
          actor: 'Ana',
        ),
      ],
      events: [_event('e1', _now.add(const Duration(days: 2)), going: 3)],
    );

    await _pump(tester, feed);

    expect(find.text('now'), findsOneWidget);
    expect(find.byType(CommunityNowDivider), findsOneWidget);

    final spotAdded = find.textContaining('has added this new spot');
    final photoAdded = find.textContaining('2 new photos');
    final checkedIn = find.textContaining('has checked in to this spot');
    final planning = find.textContaining('is planning to train at this spot');
    final eventUpcoming = find.text('This event is coming up');

    expect(spotAdded, findsOneWidget);
    expect(photoAdded, findsOneWidget);
    expect(checkedIn, findsOneWidget);
    expect(planning, findsOneWidget);
    expect(eventUpcoming, findsOneWidget);
    expect(find.text('3 people are going'), findsOneWidget);
    expect(find.textContaining('Here until'), findsOneWidget);

    // Timeline: oldest past at the top, newest just above "now", then plans
    // and events soonest first.
    final nowTop = _topOf(tester, find.byType(CommunityNowDivider));
    expect(_topOf(tester, spotAdded), lessThan(_topOf(tester, photoAdded)));
    expect(_topOf(tester, photoAdded), lessThan(_topOf(tester, checkedIn)));
    expect(_topOf(tester, checkedIn), lessThan(nowTop));
    expect(nowTop, lessThan(_topOf(tester, planning)));
    expect(_topOf(tester, planning), lessThan(_topOf(tester, eventUpcoming)));

    // Nothing to expand when the past fits the preview window.
    expect(find.textContaining('earlier update'), findsNothing);
  });

  testWidgets('collapses older history behind a "show earlier" button', (
    tester,
  ) async {
    final past = List.generate(
      CommunityActivityStream.recentPastPreviewCount + 4,
      (i) => _item(
        'c$i',
        CommunityActivityKind.spotCheckIn,
        occurredAt: _now.subtract(Duration(hours: i + 1)),
        actor: 'Person$i',
      ),
    );
    await _pump(tester, CommunityActivityFeed(past: past));

    expect(find.text('Show 4 earlier updates'), findsOneWidget);
    // Newest three are shown (indices 0..2), older ones hidden.
    expect(find.textContaining('Person0 '), findsOneWidget);
    expect(find.textContaining('Person2 '), findsOneWidget);
    expect(find.textContaining('Person3 '), findsNothing);

    await tester.tap(find.text('Show 4 earlier updates'));
    await tester.pumpAndSettle();

    expect(find.text('Show 4 earlier updates'), findsNothing);
    expect(find.textContaining('Person6 '), findsOneWidget);
  });

  testWidgets('orders plans and events together by start time', (
    tester,
  ) async {
    final feed = CommunityActivityFeed(
      upcoming: [
        _item(
          'plan',
          CommunityActivityKind.spotTrainingPlan,
          occurredAt: _now,
          startAt: _now.add(const Duration(days: 3)),
          endAt: _now.add(const Duration(days: 3, hours: 2)),
          actor: 'Ana',
        ),
      ],
      events: [
        _event('soon', _now.add(const Duration(hours: 2))),
        _event('later', _now.add(const Duration(days: 10))),
      ],
    );
    await _pump(tester, feed);

    final soon = find.text('Jam soon');
    final later = find.text('Jam later');
    final plan = find.textContaining('is planning to train');
    expect(_topOf(tester, soon), lessThan(_topOf(tester, plan)));
    expect(_topOf(tester, plan), lessThan(_topOf(tester, later)));
  });

  testWidgets('event in progress is labelled as happening now', (
    tester,
  ) async {
    await _pump(
      tester,
      CommunityActivityFeed(
        events: [_event('live', _now.subtract(const Duration(hours: 1)))],
      ),
    );
    expect(find.text('This event is happening now'), findsOneWidget);
    expect(find.text('No one has marked they are going yet'), findsOneWidget);
  });

  testWidgets('taps open the spot, the event and the actor profile', (
    tester,
  ) async {
    CommunityActivityItem? openedSpot;
    EventMapPin? openedEvent;
    String? openedActor;
    final feed = CommunityActivityFeed(
      past: [
        _item(
          'spot',
          CommunityActivityKind.spotAdded,
          occurredAt: _now.subtract(const Duration(hours: 1)),
          actor: 'Xavi',
          actorUserId: 'xavi-id',
        ),
      ],
      events: [_event('e1', _now.add(const Duration(days: 1)))],
    );
    await _pump(
      tester,
      feed,
      onOpenSpot: (item) => openedSpot = item,
      onOpenEvent: (pin) => openedEvent = pin,
      onOpenActor: (id) => openedActor = id,
    );

    await tester.tap(find.textContaining('has added this new spot'));
    expect(openedSpot?.spotId, 'spot-spot');

    await tester.tap(find.text('Jam e1'));
    expect(openedEvent?.eventId, 'e1');

    await tester.tap(find.byType(CircleAvatar));
    expect(openedActor, 'xavi-id');
  });

  testWidgets('falls back to "Someone" without a display name', (
    tester,
  ) async {
    await _pump(
      tester,
      CommunityActivityFeed(
        past: [
          _item(
            'anon',
            CommunityActivityKind.spotCheckIn,
            occurredAt: _now.subtract(const Duration(minutes: 1)),
            actor: '',
            actorUserId: null,
          ),
        ],
      ),
    );
    expect(find.text('Someone has checked in to this spot'), findsOneWidget);
    expect(find.text('1 min ago'), findsOneWidget);
  });
}
