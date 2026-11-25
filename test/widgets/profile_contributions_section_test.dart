import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/user_contribution_stats.dart';
import 'package:parkour_spot/widgets/profile_contributions_section.dart';

Future<void> pumpSection(
  WidgetTester tester,
  UserContributionStats stats, {
  bool isOwnProfile = false,
  VoidCallback? Function(ContributionKind kind)? onOpenRow,
  VoidCallback? onAddSpot,
  double width = 400,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: ProfileContributionsSection(
                stats: stats,
                isOwnProfile: isOwnProfile,
                onOpenRow: onOpenRow,
                onAddSpot: onAddSpot,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('buildContributionGroups', () {
    test('drops zero rows and empty groups, keeping display order', () {
      final groups = buildContributionGroups(
        const UserContributionStats(spotsAdded: 4, ratings: 23, checkIns: 2),
      );
      expect(groups.map((g) => g.kind), [
        ContributionGroupKind.map,
        ContributionGroupKind.people,
        ContributionGroupKind.guide,
      ]);
      expect(groups[0].rows.map((r) => r.kind), [ContributionKind.spotsAdded]);
      expect(groups[1].rows.map((r) => r.kind), [ContributionKind.checkIns]);
      expect(groups[2].rows.single.count, 23);
    });

    test('returns no groups without contributions', () {
      expect(buildContributionGroups(UserContributionStats.empty), isEmpty);
    });
  });

  group('ProfileContributionsSection', () {
    testWidgets('shows only the kinds a person contributed', (tester) async {
      await pumpSection(
        tester,
        const UserContributionStats(spotsAdded: 1, photosAdded: 9),
      );
      expect(find.text('Contributions'), findsOneWidget);
      expect(find.text('Building the map'), findsOneWidget);
      expect(find.text('spot added'), findsOneWidget);
      expect(find.text('photos added'), findsOneWidget);
      expect(find.text('Guiding others'), findsNothing);
      expect(find.text('Bringing people together'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders nothing on someone else\'s empty profile', (
      tester,
    ) async {
      await pumpSection(tester, UserContributionStats.empty);
      expect(find.text('Contributions'), findsNothing);
    });

    testWidgets('invites a first spot on your own empty profile', (
      tester,
    ) async {
      var added = 0;
      await pumpSection(
        tester,
        UserContributionStats.empty,
        isOwnProfile: true,
        onAddSpot: () => added++,
      );
      expect(find.text('Your contributions show up here'), findsOneWidget);
      await tester.tap(find.text('Add a spot'));
      expect(added, 1);
    });

    testWidgets('links rows that have a destination', (tester) async {
      final opened = <ContributionKind>[];
      await pumpSection(
        tester,
        const UserContributionStats(spotsAdded: 12, spotsImproved: 3),
        onOpenRow: (kind) =>
            kind == ContributionKind.spotsAdded ? () => opened.add(kind) : null,
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('spots added'));
      await tester.tap(find.text('spots improved'));
      expect(opened, [ContributionKind.spotsAdded]);
    });

    testWidgets('lays groups side by side when wide, stacked when narrow', (
      tester,
    ) async {
      const stats = UserContributionStats(
        spotsAdded: 271,
        eventsCreated: 2,
        ratings: 84,
      );
      await pumpSection(tester, stats, width: 760);
      final wideMap = tester.getTopLeft(find.text('Building the map'));
      final wideGuide = tester.getTopLeft(find.text('Guiding others'));
      expect(wideGuide.dy, wideMap.dy);

      await pumpSection(tester, stats, width: 360);
      final narrowMap = tester.getTopLeft(find.text('Building the map'));
      final narrowGuide = tester.getTopLeft(find.text('Guiding others'));
      expect(narrowGuide.dy, greaterThan(narrowMap.dy));
      expect(
        tester.getTopLeft(find.text('Guiding others')).dx,
        narrowMap.dx,
        reason: 'stacked groups share one left edge, no 2 + 1 orphan',
      );
      expect(
        tester.getTopLeft(find.text('spots rated')).dx,
        tester.getTopLeft(find.text('events created')).dx,
        reason: 'one count column across groups keeps labels aligned',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long German labels fit a phone width without overflow', (
      tester,
    ) async {
      await pumpSection(
        tester,
        const UserContributionStats(
          spotsAdded: 140,
          spotsImproved: 40,
          photosAdded: 129,
          eventsCreated: 1,
          trainingPlans: 1,
          ratings: 3,
          lists: 1,
        ),
        width: 320,
        locale: const Locale('de'),
      );
      expect(find.text('Leute zusammenbringen'), findsOneWidget);
      expect(find.text('Sessions geplant'), findsNothing);
      expect(find.text('Session geplant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UserContributionStats', () {
    test('reads all-time and yearly totals, ignoring junk values', () {
      final data = <String, dynamic>{
        'allTime': {'spotsAdded': 5, 'ratings': -1, 'lists': 'x'},
        'years': {
          '2026': {'spotsAdded': 3, 'checkIns': 2.0},
        },
      };
      final allTime = UserContributionStats.allTimeFromDocument(data);
      expect(allTime.spotsAdded, 5);
      expect(allTime.ratings, 0);
      expect(allTime.lists, 0);
      final year = UserContributionStats.yearFromDocument(data, 2026);
      expect(year.total, 5);
      expect(UserContributionStats.yearFromDocument(data, 2025).isEmpty, true);
      expect(UserContributionStats.allTimeFromDocument(null).isEmpty, true);
    });
  });
}
