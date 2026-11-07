import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/event_interest.dart';
import 'package:parkour_spot/widgets/event_interest_panel.dart';

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
  testWidgets('shows action labels without counts, and disclaimer', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      selected: EventInterestStatus.going,
      goingCount: 3,
      interestedCount: 12,
      people: const [
        EventInterestPerson(
          userId: 'u1',
          status: EventInterestStatus.going,
          displayName: 'Ada',
        ),
      ],
    );

    expect(find.text('Going'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
    expect(find.text('Going (3)'), findsNothing);
    expect(find.text('Interested (12)'), findsNothing);
    expect(find.text('1 person · see who\'s coming'), findsOneWidget);
    expect(
      find.text(
        'Not a registration — marks show publicly on this event.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows past-tense action labels and disclaimer when ended', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      selected: EventInterestStatus.going,
      goingCount: 3,
      interestedCount: 12,
      isPast: true,
      people: const [
        EventInterestPerson(
          userId: 'u1',
          status: EventInterestStatus.going,
          displayName: 'Ada',
        ),
      ],
    );

    expect(find.text('Attended'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
    expect(find.text('Attended (3)'), findsNothing);
    expect(
      find.text(
        'Not a registration — just who marked they attended or were interested.',
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

    await tester.tap(find.text('Going'));
    await tester.tap(find.text('Interested'));
    expect(goingTaps, 1);
    expect(interestedTaps, 1);
  });

  testWidgets('does not invoke callbacks while busy', (tester) async {
    var goingTaps = 0;
    await pumpPanel(tester, isBusy: true, onGoing: () => goingTaps += 1);

    await tester.tap(find.text('Going'));
    expect(goingTaps, 0);
  });

  testWidgets('shows crew strip totals and opens people dialog', (tester) async {
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

    expect(find.text('2 people · see who\'s coming'), findsOneWidget);
    await tester.tap(find.text('2 people · see who\'s coming'));
    expect(peopleTaps, 1);
  });

  testWidgets('people dialog lists status badges including past Attended', (
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

    expect(find.text('Who was there'), findsOneWidget);
    expect(find.text('1 attended · 1 interested'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Attended'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
  });

  testWidgets('hides people strip when empty and loaded', (tester) async {
    await pumpPanel(tester, goingCount: 0, interestedCount: 0, people: const []);
    expect(find.textContaining('see who\'s coming'), findsNothing);
    expect(find.textContaining('marked interest'), findsNothing);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('Interested'), findsOneWidget);
  });
}
