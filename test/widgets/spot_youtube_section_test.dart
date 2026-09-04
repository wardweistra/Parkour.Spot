import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/spot_form/youtube_section.dart';

Future<void> pumpYoutubeSection(
  WidgetTester tester, {
  required List<TextEditingController> controllers,
  VoidCallback? onAdd,
  void Function(int index)? onRemove,
  void Function(int oldIndex, int newIndex)? onReorder,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpotYoutubeSection(
            controllers: controllers,
            onAdd: onAdd ?? () {},
            onRemove: onRemove ?? (_) {},
            onReorder: onReorder ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows empty state and add button', (tester) async {
    var addCount = 0;
    await pumpYoutubeSection(
      tester,
      controllers: [],
      onAdd: () => addCount++,
    );

    expect(find.text('YouTube links'), findsOneWidget);
    expect(
      find.text('No YouTube links added. Click the + button to add one.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Add YouTube link'), findsOneWidget);

    await tester.tap(find.byTooltip('Add YouTube link'));
    expect(addCount, 1);
  });

  testWidgets('shows reorder handles for multiple links', (tester) async {
    final controllers = [
      TextEditingController(text: 'aaa111bbb22'),
      TextEditingController(text: 'ccc333ddd44'),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    var reordered = false;
    await pumpYoutubeSection(
      tester,
      controllers: controllers,
      onReorder: (oldIndex, newIndex) {
        reordered = true;
        final moved = controllers.removeAt(oldIndex);
        controllers.insert(newIndex, moved);
      },
    );

    expect(find.text('YouTube link 1'), findsOneWidget);
    expect(find.text('YouTube link 2'), findsOneWidget);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.byTooltip('Remove YouTube link'), findsNWidgets(2));
    expect(reordered, isFalse);
  });

  testWidgets('dragging a row does not throw Material ancestor error', (
    tester,
  ) async {
    final controllers = [
      TextEditingController(text: 'aaa111bbb22'),
      TextEditingController(text: 'ccc333ddd44'),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    await pumpYoutubeSection(tester, controllers: controllers);

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('remove button reports the row index', (tester) async {
    final controllers = [
      TextEditingController(text: 'aaa111bbb22'),
      TextEditingController(text: 'ccc333ddd44'),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    int? removedIndex;
    await pumpYoutubeSection(
      tester,
      controllers: controllers,
      onRemove: (index) => removedIndex = index,
    );

    await tester.tap(find.byTooltip('Remove YouTube link').last);
    expect(removedIndex, 1);
  });
}
