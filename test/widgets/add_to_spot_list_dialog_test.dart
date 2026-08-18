import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/widgets/add_to_spot_list_dialog.dart';

SpotList buildList({
  String id = 'list-1',
  String name = 'Jam list',
  String? description,
  List<SpotListSection>? sections,
  List<String> spotIds = const ['s1'],
}) {
  return SpotList(
    id: id,
    name: name,
    description: description,
    spotIds: spotIds,
    sections: sections,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

Future<void> openDialog(
  WidgetTester tester, {
  required List<SpotList> lists,
  List<SpotList> listsWithSpot = const [],
  required Future<bool> Function(String listId, {String? sectionId}) addSpot,
  Future<bool> Function(String listId, {String? sectionTitle})?
  addToNewSection,
  Future<String?> Function({
    required String name,
    String? description,
    required SpotListVisibility visibility,
  })?
  createList,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              showDialog<AddToSpotListDialogResult>(
                context: context,
                builder: (_) => AddToSpotListDialog(
                  lists: lists,
                  listsWithSpot: listsWithSpot,
                  addSpot: addSpot,
                  addToNewSection:
                      addToNewSection ??
                      (listId, {sectionTitle}) async => true,
                  createList:
                      createList ??
                      ({
                        required name,
                        description,
                        required visibility,
                      }) async => 'new-list',
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a plain list adds immediately', (tester) async {
    String? addedListId;
    String? addedSectionId;

    await openDialog(
      tester,
      lists: [
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
          ],
        ),
      ],
      addSpot: (listId, {sectionId}) async {
        addedListId = listId;
        addedSectionId = sectionId;
        return true;
      },
    );

    expect(find.text('Jam list'), findsOneWidget);
    expect(find.text('Add note'), findsNothing);
    await tester.tap(find.text('Jam list'));
    await tester.pumpAndSettle();

    expect(addedListId, 'list-1');
    expect(addedSectionId, isNull);
    expect(find.byType(AddToSpotListDialog), findsNothing);
  });

  testWidgets('named list asks for a section in the same sheet', (
    tester,
  ) async {
    String? addedListId;
    String? addedSectionId;

    await openDialog(
      tester,
      lists: [
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              title: 'Warmup',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(
              id: 'sec-2',
              title: 'Lines',
              entries: [SpotListEntry(spotId: 's2')],
            ),
          ],
        ),
      ],
      addSpot: (listId, {sectionId}) async {
        addedListId = listId;
        addedSectionId = sectionId;
        return true;
      },
    );

    expect(find.text('Add to new section'), findsNothing);
    await tester.tap(find.text('Jam list'));
    await tester.pump();

    expect(find.text('Warmup'), findsOneWidget);
    expect(find.text('Lines'), findsOneWidget);
    expect(find.text('Add to new section'), findsOneWidget);
    expect(find.text('Add note'), findsNothing);

    await tester.tap(find.text('Lines'));
    await tester.pumpAndSettle();

    expect(addedListId, 'list-1');
    expect(addedSectionId, 'sec-2');
    expect(find.byType(AddToSpotListDialog), findsNothing);
  });

  testWidgets('new section is added from the section sheet', (tester) async {
    String? newListId;
    String? newSectionTitle;

    await openDialog(
      tester,
      lists: [
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              title: 'Warmup',
              entries: [SpotListEntry(spotId: 's1')],
            ),
          ],
        ),
      ],
      addSpot: (listId, {sectionId}) async => true,
      addToNewSection: (listId, {sectionTitle}) async {
        newListId = listId;
        newSectionTitle = sectionTitle;
        return true;
      },
    );

    await tester.tap(find.text('Jam list'));
    await tester.pump();

    await tester.tap(find.text('Add to new section'));
    await tester.pump();
    expect(find.text('Section name (optional)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Section name (optional)'),
      'Cooldown',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    expect(newListId, 'list-1');
    expect(newSectionTitle, 'Cooldown');
    expect(find.byType(AddToSpotListDialog), findsNothing);
  });

  testWidgets('create form stays in the sheet and has no section extras', (
    tester,
  ) async {
    await openDialog(
      tester,
      lists: [buildList()],
      addSpot: (listId, {sectionId}) async => true,
    );

    expect(find.text('Create New List'), findsOneWidget);
    expect(find.text('Add note'), findsNothing);

    await tester.tap(find.text('Create New List'));
    await tester.pump();

    expect(find.text('List Name'), findsOneWidget);
    expect(find.text('Create & Add'), findsOneWidget);
    expect(find.text('Add to new section'), findsNothing);
    expect(find.text('Add note'), findsNothing);
  });
}
