import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/event_interest.dart';
import 'package:parkour_spot/widgets/event_interest_panel.dart';
import 'package:parkour_spot/widgets/stacked_user_avatars.dart';

Future<void> pumpPanel(
  WidgetTester tester, {
  EventInterestStatus? selected,
  int goingCount = 0,
  int interestedCount = 0,
  bool isBusy = false,
  bool isPast = false,
  List<EventInterestPerson> people = const [],
  bool peopleLoaded = true,
  VoidCallback? onGoing,
  VoidCallback? onInterested,
  VoidCallback? onPeople,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EventInterestPanel(
          selected: selected,
          goingCount: goingCount,
          interestedCount: interestedCount,
          isBusy: isBusy,
          isPast: isPast,
          people: people,
          peopleLoaded: peopleLoaded,
          onGoingPressed: onGoing ?? () {},
          onInterestedPressed: onInterested ?? () {},
          onPeoplePressed: onPeople,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows totals, disclaimer, and selected Going state', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      selected: EventInterestStatus.going,
      goingCount: 3,
      interestedCount: 12,
    );

    expect(find.text('Going (3)'), findsOneWidget);
    expect(find.text('Interested (12)'), findsOneWidget);
    expect(
      find.text(
        'This is not a registration. Your name and photo appear publicly on this event if you mark Going or Interested.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows past-tense labels and disclaimer when event has ended', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      selected: EventInterestStatus.going,
      goingCount: 3,
      interestedCount: 12,
      isPast: true,
    );

    expect(find.text('Attended (3)'), findsOneWidget);
    expect(find.text('Interested (12)'), findsOneWidget);
    expect(
      find.text(
        'This is not a registration. It shows who publicly marked they attended or were interested.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Going and Interested invokes callbacks', (tester) async {
    var goingTaps = 0;
    var interestedTaps = 0;
    await pumpPanel(
      tester,
      onGoing: () => goingTaps += 1,
      onInterested: () => interestedTaps += 1,
    );

    await tester.tap(find.text('Going (0)'));
    await tester.tap(find.text('Interested (0)'));
    expect(goingTaps, 1);
    expect(interestedTaps, 1);
  });

  testWidgets('does not invoke callbacks while busy', (tester) async {
    var goingTaps = 0;
    await pumpPanel(tester, isBusy: true, onGoing: () => goingTaps += 1);

    await tester.tap(find.text('Going (0)'));
    expect(goingTaps, 0);
  });

  testWidgets('shows avatar stack and opens people dialog', (tester) async {
    var peopleTaps = 0;
    await pumpPanel(
      tester,
      goingCount: 1,
      interestedCount: 1,
      people: const [
        EventInterestPerson(
          userId: 'u1',
          status: EventInterestStatus.going,
          displayName: 'Ada',
        ),
        EventInterestPerson(
          userId: 'u2',
          status: EventInterestStatus.interested,
          displayName: 'Bea',
        ),
      ],
      onPeople: () => peopleTaps += 1,
    );

    expect(find.byType(StackedUserAvatars), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    await tester.tap(find.text('View all'));
    expect(peopleTaps, 1);
  });

  testWidgets('people dialog lists status labels including past Attended', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showEventInterestPeopleDialog(
                  context,
                  isPast: true,
                  people: const [
                    EventInterestPerson(
                      userId: 'u1',
                      status: EventInterestStatus.going,
                      displayName: 'Ada',
                    ),
                    EventInterestPerson(
                      userId: 'u2',
                      status: EventInterestStatus.interested,
                      displayName: 'Bea',
                    ),
                  ],
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Who marked interest'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Attended'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
  });

  testWidgets('hides people strip when empty and loaded', (tester) async {
    await pumpPanel(tester, goingCount: 0, interestedCount: 0, people: const []);
    expect(find.byType(StackedUserAvatars), findsNothing);
    expect(find.text('View all'), findsNothing);
  });
}
