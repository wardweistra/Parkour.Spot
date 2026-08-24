import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/spot_duplicate_review.dart';
import 'package:parkour_spot/widgets/spot_duplicate_changes_dialog.dart';

void main() {
  Future<SpotDuplicateChangesResult?> pumpDialog(
    WidgetTester tester, {
    required List<SpotDuplicateFieldGroup> changedGroups,
    required Future<void> Function(WidgetTester tester) interact,
  }) async {
    SpotDuplicateChangesResult? result;
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
                result = await showDialog<SpotDuplicateChangesResult>(
                  context: context,
                  builder: (_) => SpotDuplicateChangesDialog(
                    duplicateSpot: Spot(
                      id: 'dup-1',
                      name: 'Updated name',
                      description: 'New description',
                      latitude: 50.8,
                      longitude: 4.3,
                      duplicateOf: 'orig-1',
                      duplicateHasPendingChanges: true,
                      duplicateChangedFields: changedGroups
                          .map((group) => group.firestoreValue)
                          .toList(),
                    ),
                    originalName: 'Original Rails',
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
        SpotDuplicateFieldGroup.name,
        SpotDuplicateFieldGroup.location,
      ],
      interact: (tester) async {},
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Updated name'), findsOneWidget);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Description'), findsNothing);
    expect(find.text('YouTube links'), findsNothing);
  });

  testWidgets('apply returns selected overwrite flags', (tester) async {
    final result = await pumpDialog(
      tester,
      changedGroups: const [
        SpotDuplicateFieldGroup.name,
        SpotDuplicateFieldGroup.description,
      ],
      interact: (tester) async {
        await tester.tap(find.text('Name'));
        await tester.tap(find.text('Apply'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isFalse);
    expect(result.overwriteName, isTrue);
    expect(result.overwriteDescription, isFalse);
  });

  testWidgets('dismiss returns dismissed result without applying fields', (
    tester,
  ) async {
    final result = await pumpDialog(
      tester,
      changedGroups: const [SpotDuplicateFieldGroup.name],
      interact: (tester) async {
        await tester.tap(find.text('Name'));
        await tester.tap(find.text('Dismiss'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isTrue);
    expect(result.overwriteName, isFalse);
  });
}
