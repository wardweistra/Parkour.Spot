import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/widgets/event_duplicate_transfer_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required ParkourEvent duplicate,
  }) async {
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
              onPressed: () {
                showDialog<EventDuplicateTransferResult>(
                  context: context,
                  builder: (_) => EventDuplicateTransferDialog(
                    duplicateEvent: duplicate,
                    originalTitle: 'Original Jam',
                    showReportSelector: false,
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
  }

  testWidgets('shows transfer and overwrite options when duplicate has data',
      (tester) async {
    await pumpDialog(
      tester,
      duplicate: ParkourEvent(
        id: 'dup-1',
        title: 'Dup Title',
        description: 'A description',
        imageUrls: const ['https://example.com/p.jpg'],
        websiteUrl: 'https://example.com',
        latitude: 50,
        longitude: 4,
        spotIds: const ['spot-1'],
        startAt: DateTime.utc(2026, 7, 1),
      ),
    );

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Linked spots'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
  });

  testWidgets('hides add options when duplicate has no photos or spots',
      (tester) async {
    await pumpDialog(
      tester,
      duplicate: ParkourEvent(
        id: 'dup-2',
        title: 'Dup Title',
        startAt: DateTime.utc(2026, 7, 1),
      ),
    );

    expect(find.text('Photos'), findsNothing);
    expect(find.text('Linked spots'), findsNothing);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });
}
