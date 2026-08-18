import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/models/spot_list_edit_draft.dart';
import 'package:parkour_spot/screens/spots/spot_list_detail_edit_body.dart';
import 'package:parkour_spot/widgets/spot_list_edit_spot_row.dart';

SpotList buildList() {
  return SpotList(
    id: 'list-1',
    name: 'Downtown session',
    description: 'A loop through the centre',
    spotIds: const ['s1', 's2'],
    sections: [
      SpotListSection(
        id: 'sec-1',
        title: 'Warmup',
        entries: [
          SpotListEntry(spotId: 's1'),
          SpotListEntry(spotId: 's2', note: 'Mind the rail'),
        ],
      ),
    ],
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

Spot buildSpot(String id, String name) {
  return Spot(
    id: id,
    name: name,
    description: '',
    latitude: 51.05,
    longitude: 3.72,
    city: 'Ghent',
    countryCode: 'BE',
  );
}

Future<void> pumpEditBody(
  WidgetTester tester,
  SpotListEditDraft draft, {
  Future<List<Spot>?> Function()? pickSpots,
  ValueChanged<List<Spot>>? onSpotsAdded,
  Map<String, Spot>? spotsById,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SpotListDetailEditBody(
              draft: draft,
              spotsById:
                  spotsById ??
                  {
                    's1': buildSpot('s1', 'Library wall'),
                    's2': buildSpot('s2', 'Station rails'),
                  },
              onChanged: () {},
              onSpotsAdded: onSpotsAdded,
              pickSpots: pickSpots ?? () async => null,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('edit body shows metadata fields and compact spot rows', (
    tester,
  ) async {
    final draft = SpotListEditDraft.fromList(buildList());
    await pumpEditBody(tester, draft);

    expect(find.text('Downtown session'), findsOneWidget);
    expect(find.text('A loop through the centre'), findsOneWidget);
    expect(find.text('Warmup'), findsOneWidget);
    expect(find.text('Library wall'), findsOneWidget);
    expect(find.text('Station rails'), findsOneWidget);
    expect(find.text('Mind the rail'), findsOneWidget);
    expect(find.byType(SpotListEditSpotRow), findsNWidgets(2));
    expect(find.byType(SliverReorderableList), findsOneWidget);
    expect(find.byType(SliverLayoutBuilder), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    expect(find.byIcon(Icons.note), findsNothing);
    expect(find.text('Add note'), findsOneWidget);
    expect(find.byTooltip('Edit section'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Warmup'), findsNothing);
  });

  testWidgets('section title stays read-only until the pencil is tapped', (
    tester,
  ) async {
    final draft = SpotListEditDraft.fromList(buildList());
    await pumpEditBody(tester, draft);

    expect(find.text('Warmup'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit section'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Warmup'), findsOneWidget);
    expect(find.byTooltip('Done'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Warmup'),
      'Cool down',
    );
    await tester.tap(find.byTooltip('Done'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Cool down'), findsNothing);
    expect(find.text('Cool down'), findsOneWidget);
    expect(draft.sections.single.title, 'Cool down');
  });

  testWidgets('note block expands to an editor and can clear the note', (
    tester,
  ) async {
    final draft = SpotListEditDraft.fromList(buildList());
    await pumpEditBody(tester, draft);

    await tester.tap(find.text('Mind the rail'));
    await tester.pump();

    expect(find.byType(TextField), findsWidgets);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byTooltip('Remove note'));
    await tester.pump();

    expect(find.text('Mind the rail'), findsNothing);
    expect(draft.sections.single.entries[1].note, isNull);
    expect(find.text('Add note'), findsNWidgets(2));
  });

  testWidgets('discard dialog offers cancel and discard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmDiscardSpotListEdits(context),
              child: const Text('open-discard'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Your edits to this list will be lost.'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('section header has an add-spots control', (tester) async {
    final draft = SpotListEditDraft.fromList(buildList());
    await pumpEditBody(tester, draft);

    expect(find.byTooltip('Add spots to this section'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_outlined), findsOneWidget);
  });

  testWidgets('empty section add-spots button appends picker results', (
    tester,
  ) async {
    final draft = SpotListEditDraft.fromList(
      SpotList(
        id: 'list-1',
        name: 'Downtown session',
        spotIds: const [],
        sections: [SpotListSection(id: 'sec-1', title: 'Warmup', entries: [])],
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    final added = <Spot>[];

    await pumpEditBody(
      tester,
      draft,
      spotsById: {
        's3': buildSpot('s3', 'Canal ledge'),
        's4': buildSpot('s4', 'Roof gap'),
      },
      pickSpots: () async => [
        buildSpot('s3', 'Canal ledge'),
        buildSpot('s4', 'Roof gap'),
      ],
      onSpotsAdded: added.addAll,
    );

    expect(find.text('No spots in this section'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add spots'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add spots'));
    await tester.pumpAndSettle();

    expect(draft.sections.single.entries.map((e) => e.spotId), ['s3', 's4']);
    expect(added.map((s) => s.id), ['s3', 's4']);
    expect(find.text('Canal ledge'), findsOneWidget);
    expect(find.text('Roof gap'), findsOneWidget);
  });
}
