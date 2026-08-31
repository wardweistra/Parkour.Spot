import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/confirm_disable_push_dialog.dart';

void main() {
  testWidgets('confirm disable push: cancel does not confirm', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => confirmDisablePushNotifications(context),
              child: const Text('disable'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('disable'));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.profilePushNotificationsDisableTitle),
      findsOneWidget,
    );
    expect(
      find.text(l10n.profilePushNotificationsDisableMessage),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.profileCancel));
    await tester.pumpAndSettle();

    expect(find.text(l10n.profilePushNotificationsDisableTitle), findsNothing);
  });

  testWidgets('confirm disable push: confirm returns true', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                confirmed = await confirmDisablePushNotifications(context);
              },
              child: const Text('disable'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('disable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.profilePushNotificationsDisableConfirm));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
