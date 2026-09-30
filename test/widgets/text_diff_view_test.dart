import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/text_diff_view.dart';

void main() {
  testWidgets('renders unified delete and insert lines for a text change', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextDiffView(
            before: 'Old title',
            after: 'New title',
          ),
        ),
      ),
    );

    expect(find.textContaining('Old title'), findsOneWidget);
    expect(find.textContaining('New title'), findsOneWidget);
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
  });

  testWidgets('renders unchanged text without gutter markers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextDiffView(
            before: 'Same value',
            after: 'Same value',
          ),
        ),
      ),
    );

    expect(find.textContaining('Same value'), findsOneWidget);
    expect(find.text('−'), findsNothing);
    expect(find.text('+'), findsNothing);
  });
}
