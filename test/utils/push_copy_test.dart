import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/utils/push_copy.dart';

void main() {
  group('PushCopy', () {
    test('web talks about the browser, native about the device', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final web = PushCopy(l10n, isWeb: true);
      final native = PushCopy(l10n, isWeb: false);

      expect(web.enabled, l10n.profilePushNotificationsEnabled);
      expect(web.enabled, contains('browser'));
      expect(native.enabled, l10n.profilePushNotificationsEnabledDevice);
      expect(native.enabled, contains('device'));
    });

    test('native copy never mentions a browser, in any language', () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final native = PushCopy(
          await AppLocalizations.delegate.load(locale),
          isWeb: false,
        );
        final all = [
          native.promptListTitle,
          native.promptTurnOnEmpty,
          native.promptBlockedTitle,
          native.promptBlockedBody,
          native.promptEnabledSnackbar,
          native.thisDeviceGroupHelper,
          native.unsupported,
          native.permissionDenied,
          native.permissionNotDetermined,
          native.enabled,
          native.permissionGrantedButOff,
          native.error,
          native.disableMessage,
        ];
        for (final text in all) {
          expect(
            text.toLowerCase(),
            isNot(
              anyOf(
                contains('browser'),
                contains('navega'),
                contains('navigateur'),
              ),
            ),
            reason: '${locale.languageCode}: $text',
          );
        }
      }
    });
  });
}
