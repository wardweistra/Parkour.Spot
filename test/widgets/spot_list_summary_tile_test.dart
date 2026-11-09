import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/widgets/spot_list_summary_tile.dart';

SpotList buildList({
  String name = 'City jam',
  String? description = 'Rooftops and rails',
  List<String> spotIds = const ['s1', 's2', 's3'],
  bool featured = false,
}) {
  return SpotList(
    id: 'list-1',
    name: name,
    description: description,
    spotIds: spotIds,
    visibility: SpotListVisibility.public,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    featured: featured,
  );
}

Future<void> pumpTile(
  WidgetTester tester,
  SpotList list, {
  bool showCreator = false,
  String? creatorName,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SpotListSummaryTile(
          list: list,
          showCreator: showCreator,
          creatorName: creatorName,
          onTap: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows name, description, visibility, and count', (tester) async {
    await pumpTile(tester, buildList());

    expect(find.text('City jam'), findsOneWidget);
    expect(find.text('Rooftops and rails'), findsOneWidget);
    expect(find.text('Public list with 3 spots'), findsOneWidget);
  });

  testWidgets('ellipsizes a long name without overflowing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTile(
      tester,
      buildList(
        name:
            'A very long parkour list name that should wrap or ellipsize instead of overflowing the row',
        description:
            'An equally long description that must stay inside two lines so the hub stays scannable on a phone.',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows creator in a single attribution sentence', (tester) async {
    await pumpTile(
      tester,
      buildList(featured: true),
      showCreator: true,
      creatorName: 'Ada Vault',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Public list with 3 spots by Ada Vault'),
      findsOneWidget,
    );
    expect(find.text('Featured'), findsOneWidget);
  });
}
