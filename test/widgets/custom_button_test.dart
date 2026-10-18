import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/custom_button.dart';

void main() {
  testWidgets('idle button shows label and icon without a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomButton(
            onPressed: _noop,
            text: 'Add spot',
            icon: Icons.add_location,
          ),
        ),
      ),
    );

    expect(find.text('Add spot'), findsOneWidget);
    expect(find.byIcon(Icons.add_location), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading button shows spinner and status text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomButton(
            onPressed: _noop,
            text: 'Uploading... (1 / 3)',
            isLoading: true,
            icon: Icons.add_location,
          ),
        ),
      ),
    );

    expect(find.text('Uploading... (1 / 3)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.add_location), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('loading button keeps the active fill color', (tester) async {
    const seed = Color(0xFF006C49);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: CustomButton(
            onPressed: _noop,
            text: 'Adding spot...',
            isLoading: true,
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(CustomButton));
    final scheme = Theme.of(context).colorScheme;
    final style = tester
        .widget<ElevatedButton>(find.byType(ElevatedButton))
        .style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.disabled}),
      scheme.primary,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      scheme.onPrimary,
    );
  });
}

void _noop() {}
