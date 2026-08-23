import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_duplicate_review.dart';
import 'package:parkour_spot/widgets/event_duplicate_changes_dialog.dart';

void main() {
  Future<EventDuplicateChangesResult?> pumpDialog(
    WidgetTester tester, {
    required List<EventDuplicateFieldGroup> changedGroups,
    required Future<void> Function(WidgetTester tester) interact,
  }) async {
    EventDuplicateChangesResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<EventDuplicateChangesResult>(
                  context: context,
                  builder: (_) => EventDuplicateChangesDialog(
                    duplicateEvent: ParkourEvent(
                      id: 'dup-1',
                      title: 'Updated title',
                      description: 'New description',
                      websiteUrl: 'https://example.com/new',
                      startAt: DateTime.utc(2026, 7, 2),
                      duplicateOf: 'orig-1',
                      duplicateHasPendingChanges: true,
                      duplicateChangedFields: changedGroups
                          .map((group) => group.firestoreValue)
                          .toList(),
                    ),
                    originalTitle: 'Original Jam',
                    changedGroups: changedGroups,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await interact(tester);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows only changed field groups', (tester) async {
    await pumpDialog(
      tester,
      changedGroups: const [
        EventDuplicateFieldGroup.title,
        EventDuplicateFieldGroup.schedule,
      ],
      interact: (tester) async {},
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Description'), findsNothing);
    expect(find.text('Website'), findsNothing);
  });

  testWidgets('apply returns selected overwrite flags', (tester) async {
    final result = await pumpDialog(
      tester,
      changedGroups: const [
        EventDuplicateFieldGroup.title,
        EventDuplicateFieldGroup.website,
      ],
      interact: (tester) async {
        await tester.tap(find.text('Title'));
        await tester.tap(find.text('Apply'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isFalse);
    expect(result.overwriteTitle, isTrue);
    expect(result.overwriteWebsite, isFalse);
  });

  testWidgets('dismiss returns dismissed result without applying fields', (
    tester,
  ) async {
    final result = await pumpDialog(
      tester,
      changedGroups: const [EventDuplicateFieldGroup.title],
      interact: (tester) async {
        await tester.tap(find.text('Title'));
        await tester.tap(find.text('Dismiss'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isTrue);
    expect(result.overwriteTitle, isFalse);
  });
}
