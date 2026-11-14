import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/page_scaffold.dart';
import 'package:parkour_spot/widgets/system_back_handler.dart';

void main() {
  group('SystemBackHandler', () {
    testWidgets('runs onBack when the page is the only one on the stack', (
      tester,
    ) async {
      var backCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SystemBackHandler(
            onBack: () => backCalls++,
            child: const Scaffold(body: Text('root')),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(backCalls, 1);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('lets a pushed page pop normally', (tester) async {
      var backCalls = 0;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('root')),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SystemBackHandler(
            onBack: () => backCalls++,
            child: const Scaffold(body: Text('pushed')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(backCalls, 0);
      expect(find.text('pushed'), findsNothing);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('stays out of the way when disabled', (tester) async {
      var backCalls = 0;
      var ownerCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) ownerCalls++;
            },
            child: SystemBackHandler(
              enabled: false,
              onBack: () => backCalls++,
              child: const Scaffold(body: Text('root')),
            ),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(ownerCalls, 1);
      expect(backCalls, 0);
    });
  });

  group('PageScaffold system back', () {
    testWidgets('uses the page back action at the bottom of the stack', (
      tester,
    ) async {
      var backCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PageScaffold(
            title: 'Page',
            onBack: () => backCalls++,
            body: const Text('body'),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(backCalls, 1);
    });

    testWidgets('does not intercept when handleSystemBack is false', (
      tester,
    ) async {
      var backCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PageScaffold(
            title: 'Page',
            onBack: () => backCalls++,
            handleSystemBack: false,
            body: const Text('body'),
          ),
        ),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(backCalls, 0);
    });
  });
}
