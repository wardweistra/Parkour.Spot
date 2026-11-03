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

CommunityEventItem _event(
  String id,
  DateTime startAt, {
  int going = 0,
  int interested = 0,
  bool isPast = false,
  DateTime? endAt,
}) {
  final resolvedEnd = endAt ?? startAt.add(const Duration(hours: 3));
  return CommunityEventItem(
    pin: EventMapPin(
      id: 'pin-$id',
      eventId: id,
      kind: EventMapPinKind.venue,
      latitude: 52.37,
      longitude: 4.9,
      title: 'Jam $id',
      startAt: startAt,
      endAt: resolvedEnd,
    ),
    goingCount: going,
    interestedCount: interested,
    isPast: isPast,
  );
}

Future<void> _pump(
  WidgetTester tester,
  CommunityActivityFeed feed, {
  ValueChanged<CommunityActivityItem>? onOpenSpot,
  ValueChanged<EventMapPin>? onOpenEvent,
  ValueChanged<String>? onOpenActor,
  VoidCallback? onLoadMorePast,
  VoidCallback? onLoadMoreUpcoming,
  bool loadingMorePast = false,
  bool loadingMoreUpcoming = false,
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
          onLoadMorePast: onLoadMorePast,
          onLoadMoreUpcoming: onLoadMoreUpcoming,
          loadingMorePast: loadingMorePast,
          loadingMoreUpcoming: loadingMoreUpcoming,
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

    // No server paging affordance when the feed says there is nothing more.
    expect(find.textContaining('earlier activity'), findsNothing);
    expect(find.text('Show more upcoming'), findsNothing);
  });

  testWidgets('shows load-more past when hasMorePast and calls the callback', (
    tester,
  ) async {
    var loadMorePastCalls = 0;
    final past = List.generate(
      3,
      (i) => _item(
        'c$i',
        CommunityActivityKind.spotCheckIn,
        occurredAt: _now.subtract(Duration(hours: i + 1)),
        actor: 'Person$i',
      ),
    );
    await _pump(
      tester,
      CommunityActivityFeed(
        past: past,
        pastTotal: 7,
        hasMorePast: true,
      ),
      onLoadMorePast: () => loadMorePastCalls++,
    );

    expect(find.text('Show 4 earlier activities'), findsOneWidget);
    expect(find.textContaining('Person0 '), findsOneWidget);
    expect(find.textContaining('Person2 '), findsOneWidget);

    await tester.tap(find.text('Show 4 earlier activities'));
    await tester.pump();
    expect(loadMorePastCalls, 1);
  });

  testWidgets('shows load-more upcoming when hasMoreUpcoming', (tester) async {
    var loadMoreUpcomingCalls = 0;
    await _pump(
      tester,
      CommunityActivityFeed(
        events: [_event('soon', _now.add(const Duration(hours: 2)))],
        hasMoreUpcoming: true,
      ),
      onLoadMoreUpcoming: () => loadMoreUpcomingCalls++,
    );

    expect(find.text('Show more upcoming'), findsOneWidget);
    await tester.tap(find.text('Show more upcoming'));
    await tester.pump();
    expect(loadMoreUpcomingCalls, 1);
  });

  testWidgets('hides load-more buttons when paging flags are false', (
    tester,
  ) async {
    final past = List.generate(
      5,
      (i) => _item(
        'c$i',
        CommunityActivityKind.spotCheckIn,
        occurredAt: _now.subtract(Duration(hours: i + 1)),
        actor: 'Person$i',
      ),
    );
    await _pump(
      tester,
      CommunityActivityFeed(past: past, pastTotal: 5),
      onLoadMorePast: () {},
      onLoadMoreUpcoming: () {},
    );

    expect(find.textContaining('earlier activity'), findsNothing);
    expect(find.text('Show more upcoming'), findsNothing);
    // All loaded past rows are visible (no client-side collapse).
    expect(find.textContaining('Person4 '), findsOneWidget);
  });

  testWidgets('shows 90-day history limit when past paging is exhausted', (
    tester,
  ) async {
    await _pump(
      tester,
      CommunityActivityFeed(
        past: [
          _item(
            'c0',
            CommunityActivityKind.spotCheckIn,
            occurredAt: _now.subtract(const Duration(hours: 1)),
            actor: 'Alex',
          ),
        ],
        pastTotal: 1,
        hasMorePast: false,
      ),
    );

    expect(
      find.text('Only activity from the last 90 days is shown'),
      findsOneWidget,
    );
  });

  testWidgets('hides 90-day limit while more past pages remain', (tester) async {
    await _pump(
      tester,
      CommunityActivityFeed(
        past: [
          _item(
            'c0',
            CommunityActivityKind.spotCheckIn,
            occurredAt: _now.subtract(const Duration(hours: 1)),
            actor: 'Alex',
          ),
        ],
        pastTotal: 5,
        hasMorePast: true,
      ),
      onLoadMorePast: () {},
    );

    expect(
      find.text('Only activity from the last 90 days is shown'),
      findsNothing,
    );
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

  testWidgets('past events sit above now with past-tense RSVP copy', (
    tester,
  ) async {
    final feed = CommunityActivityFeed(
      past: [
        _item(
          'checkin',
          CommunityActivityKind.spotCheckIn,
          occurredAt: _now.subtract(const Duration(hours: 1)),
          actor: 'Zoë',
        ),
      ],
      pastEvents: [
        _event(
          'ended',
          _now.subtract(const Duration(days: 2)),
          endAt: _now
              .subtract(const Duration(days: 2))
              .add(const Duration(hours: 3)),
          going: 4,
          interested: 2,
          isPast: true,
        ),
      ],
      events: [_event('soon', _now.add(const Duration(days: 1)), going: 1)],
    );
    await _pump(tester, feed);

    final pastEvent = find.text('This event has ended');
    final upcomingEvent = find.text('This event is coming up');
    final nowDivider = find.byType(CommunityNowDivider);

    expect(pastEvent, findsOneWidget);
    expect(upcomingEvent, findsOneWidget);
    expect(find.text('4 people attended'), findsOneWidget);
    expect(find.text('2 were interested'), findsOneWidget);
    expect(find.text('1 person is going'), findsOneWidget);

    final nowTop = _topOf(tester, nowDivider);
    expect(_topOf(tester, pastEvent), lessThan(nowTop));
    expect(nowTop, lessThan(_topOf(tester, upcomingEvent)));
  });

  testWidgets('past events are included in remaining earlier count', (
    tester,
  ) async {
    final past = List.generate(
      2,
      (i) => _item(
        'c$i',
        CommunityActivityKind.spotCheckIn,
        occurredAt: _now.subtract(Duration(hours: i + 1)),
        actor: 'Person$i',
      ),
    );
    final pastEvents = List.generate(
      2,
      (i) => _event(
        'pe$i',
        _now.subtract(Duration(days: i + 1)),
        isPast: true,
      ),
    );
    await _pump(
      tester,
      CommunityActivityFeed(
        past: past,
        pastEvents: pastEvents,
        pastTotal: 7,
        hasMorePast: true,
      ),
      onLoadMorePast: () {},
    );

    // 4 loaded, 7 total → show 3 earlier.
    expect(find.text('Show 3 earlier activities'), findsOneWidget);
    expect(find.text('This event has ended'), findsWidgets);
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
