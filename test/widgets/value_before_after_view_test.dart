import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/value_before_after_view.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Widget child,
    double width = 800,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows current and suggested labels for scalar values', (
    tester,
  ) async {
    await pump(
      tester,
      child: const ValueBeforeAfterView(
        before: 'Public',
        after: 'Private',
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });

  testWidgets('list change view highlights added and removed chips', (
    tester,
  ) async {
    await pump(
      tester,
      child: const ListLabelChangeView(
        beforeLabels: <String>['Walls', 'Rails'],
        afterLabels: <String>['Walls', 'Gaps'],
      ),
    );

    expect(find.text('Walls'), findsNWidgets(2));
    expect(find.text('Rails'), findsOneWidget);
    expect(find.text('Gaps'), findsOneWidget);
  });
}
