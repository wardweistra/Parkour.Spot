import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/explore_bottom_sheet_header.dart';

void main() {
  testWidgets('tapping the spots segment opens a collapsed sheet', (
    tester,
  ) async {
    var mode = ExploreBottomSheetHeader.modeSpots;
    var sheetOpen = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ExploreBottomSheetHeader(
                mode: mode,
                spotsLabel: '12 spots',
                eventsLabel: '3 events',
                spotsDetailSuffix: 'best shown',
                isSheetOpen: sheetOpen,
                onModeChanged: (next) => setState(() => mode = next),
                onToggleSheet: () => setState(() => sheetOpen = !sheetOpen),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.text('12 spots'));
    await tester.pump();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('switching to events does not collapse an open sheet', (
    tester,
  ) async {
    var mode = ExploreBottomSheetHeader.modeSpots;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ExploreBottomSheetHeader(
                mode: mode,
                spotsLabel: '12 spots',
                eventsLabel: '3 events',
                isSheetOpen: true,
                onModeChanged: (next) => setState(() => mode = next),
                onToggleSheet: () {},
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('3 events'));
    await tester.pump();

    expect(find.byIcon(Icons.event), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });
}
