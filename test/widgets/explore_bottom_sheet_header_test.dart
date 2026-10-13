import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/marker_icon_utils.dart';
import 'package:parkour_spot/widgets/explore_bottom_sheet_header.dart';

Finder _mapPinImage(String assetPath) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetPath,
  );
}

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

    expect(
      _mapPinImage(MarkerIconUtils.mapPinEventAsset),
      findsOneWidget,
    );
    expect(
      _mapPinImage(MarkerIconUtils.mapPinEventSelectedAsset),
      findsNothing,
    );
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets(
    'keeps pill height when spots detail suffix stays while switching modes',
    (tester) async {
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
                  spotsDetailSuffix: '100 best shown',
                  isSheetOpen: true,
                  onModeChanged: (next) => setState(() => mode = next),
                  onToggleSheet: () {},
                );
              },
            ),
          ),
        ),
      );

      final spotsHeight = tester.getSize(find.text('12 spots')).height;
      // Measure the outer Material pill via the spots label's ancestor Material
      // that paints the toggle track (surfaceContainerHighest).
      final pillFinder = find.ancestor(
        of: find.text('12 spots'),
        matching: find.byType(Material),
      );
      final heightOnSpots = tester.getSize(pillFinder.first).height;

      await tester.tap(find.text('3 events'));
      await tester.pumpAndSettle();

      expect(find.text('100 best shown'), findsOneWidget);
      expect(tester.getSize(pillFinder.first).height, heightOnSpots);
      expect(tester.getSize(find.text('12 spots')).height, spotsHeight);
    },
  );

  testWidgets(
    'keeps pill height when spots detail suffix is absent',
    (tester) async {
      String? spotsDetailSuffix = '100 best shown';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExploreBottomSheetHeader(
                  mode: ExploreBottomSheetHeader.modeSpots,
                  spotsLabel: '12 spots',
                  eventsLabel: '3 events',
                  spotsDetailSuffix: spotsDetailSuffix,
                  isSheetOpen: true,
                  onModeChanged: (_) {},
                  onToggleSheet: () {},
                );
              },
            ),
          ),
        ),
      );

      final pillFinder = find.ancestor(
        of: find.text('12 spots'),
        matching: find.byType(Material),
      );
      final heightWithSuffix = tester.getSize(pillFinder.first).height;

      spotsDetailSuffix = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreBottomSheetHeader(
              mode: ExploreBottomSheetHeader.modeSpots,
              spotsLabel: '12 spots',
              eventsLabel: '3 events',
              isSheetOpen: true,
              onModeChanged: (_) {},
              onToggleSheet: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100 best shown'), findsNothing);
      expect(tester.getSize(pillFinder.first).height, heightWithSuffix);
    },
  );
}
