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
    ParkourEvent? originalEvent,
    Map<String, dynamic>? duplicateReviewBaseline,
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
                      duplicateReviewBaseline: duplicateReviewBaseline,
                    ),
                    originalTitle: 'Original Jam',
                    originalEvent: originalEvent,
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
        await tester.pump();
        await tester.tap(find.text('Apply selected'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isFalse);
    expect(result.overwriteTitle, isTrue);
    expect(result.overwriteWebsite, isFalse);
  });

  testWidgets('apply stays disabled until a field is selected', (tester) async {
    await pumpDialog(
      tester,
      changedGroups: const [
        EventDuplicateFieldGroup.title,
        EventDuplicateFieldGroup.website,
      ],
      interact: (tester) async {
        final apply = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Apply selected'),
        );
        expect(apply.onPressed, isNull);

        await tester.tap(find.text('Title'));
        await tester.pump();

        final enabled = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Apply selected'),
        );
        expect(enabled.onPressed, isNotNull);
      },
    );
  });

  testWidgets('dismiss returns dismissed result without applying fields', (
    tester,
  ) async {
    final result = await pumpDialog(
      tester,
      changedGroups: const [EventDuplicateFieldGroup.title],
      interact: (tester) async {
        await tester.tap(find.text('Title'));
        await tester.tap(find.text('Dismiss all'));
      },
    );

    expect(result, isNotNull);
    expect(result!.dismissed, isTrue);
    expect(result.overwriteTitle, isFalse);
  });

  testWidgets('shows updated duplicate change and omits matching original value', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      changedGroups: const [EventDuplicateFieldGroup.title],
      duplicateReviewBaseline: const {'title': 'Jam Session'},
      originalEvent: ParkourEvent(
        title: 'Jam Session',
        startAt: DateTime.utc(2026, 7, 2),
      ),
      interact: (tester) async {},
    );

    expect(find.text('Updated on duplicate'), findsOneWidget);
    expect(find.text('Jam Session'), findsOneWidget);
    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('Current on original'), findsOneWidget);
    expect(find.text('Same as previous on duplicate'), findsOneWidget);
  });

  testWidgets('shows when the original value differs from the previous one', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      changedGroups: const [EventDuplicateFieldGroup.title],
      duplicateReviewBaseline: const {'title': 'Jam Session'},
      originalEvent: ParkourEvent(
        title: 'Native jam',
        startAt: DateTime.utc(2026, 7, 2),
      ),
      interact: (tester) async {},
    );

    expect(find.text('Jam Session'), findsOneWidget);
    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Native jam'), findsOneWidget);
    expect(find.text('Differs from previous on duplicate'), findsOneWidget);
  });

  testWidgets('does not claim a match when baseline or original is missing', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      changedGroups: const [EventDuplicateFieldGroup.title],
      interact: (tester) async {},
    );

    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Previous duplicate value unavailable'), findsOneWidget);
    expect(find.text('Original event unavailable'), findsOneWidget);
    expect(find.text('Same as previous on duplicate'), findsNothing);
    expect(find.text('Differs from previous on duplicate'), findsNothing);
  });
}
