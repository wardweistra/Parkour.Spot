import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/form_submit_bar.dart';

void main() {
  testWidgets('idle bar shows the block reason and idle label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormSubmitBar(
            onPressed: null,
            idleText: 'Add spot',
            loadingText: 'Uploading... (1 / 3)',
            blockReason: 'Please upload at least one photo of the spot',
          ),
        ),
      ),
    );

    expect(
      find.text('Please upload at least one photo of the spot'),
      findsOneWidget,
    );
    expect(find.text('Add spot'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading bar shows status once, on the submit button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormSubmitBar(
            onPressed: _noop,
            idleText: 'Add spot',
            loadingText: 'Uploading... (1 / 3)',
            isLoading: true,
            blockReason: 'Please upload at least one photo of the spot',
          ),
        ),
      ),
    );

    expect(find.text('Add spot'), findsNothing);
    expect(
      find.text('Please upload at least one photo of the spot'),
      findsNothing,
    );
    expect(find.text('Uploading... (1 / 3)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading bar updates the in-view upload status', (tester) async {
    var loadingText = 'Uploading...';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  FormSubmitBar(
                    onPressed: _noop,
                    idleText: 'Add spot',
                    loadingText: loadingText,
                    isLoading: true,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        loadingText = 'Uploading... (2 / 3)';
                      });
                    },
                    child: const Text('advance'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Uploading...'), findsOneWidget);
    await tester.tap(find.text('advance'));
    await tester.pump();
    expect(find.text('Uploading... (2 / 3)'), findsOneWidget);
    expect(find.text('Add spot'), findsNothing);
  });
}

void _noop() {}
