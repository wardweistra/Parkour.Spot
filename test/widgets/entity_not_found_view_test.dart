import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/entity_not_found_view.dart';

void main() {
  testWidgets('EntityNotFoundView shows shrine, title, and contact', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EntityNotFoundView(
            title: 'Spot not found',
            primaryActionLabel: 'Go to Explore',
            onPrimaryAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Spot not found'), findsOneWidget);
    expect(find.text('Vauxhall Maze'), findsOneWidget);
    expect(find.textContaining('Keep exploring from here'), findsOneWidget);
    expect(find.text('contact us'), findsOneWidget);

    await tester.tap(find.text('Go to Explore'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
