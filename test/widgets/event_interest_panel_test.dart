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
  VoidCallback? onGoing,
  VoidCallback? onInterested,
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
          onGoingPressed: onGoing ?? () {},
          onInterestedPressed: onInterested ?? () {},
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
        'This is not a registration. It only lets others know you might be there.',
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
}
