import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/l10n/app_localizations_de.dart';
import 'package:parkour_spot/l10n/app_localizations_en.dart';
import 'package:parkour_spot/l10n/app_localizations_es.dart';
import 'package:parkour_spot/l10n/app_localizations_fr.dart';
import 'package:parkour_spot/l10n/app_localizations_nl.dart';
import 'package:parkour_spot/l10n/app_localizations_pt.dart';

void main() {
  final localizations = <AppLocalizations>[
    AppLocalizationsDe(),
    AppLocalizationsEn(),
    AppLocalizationsEs(),
    AppLocalizationsFr(),
    AppLocalizationsNl(),
    AppLocalizationsPt(),
  ];

  for (final l10n in localizations) {
    test('${l10n.localeName} names Safari for iOS installation', () {
      final intro = l10n.profileInstallIntro(
        l10n.profileInstallDeviceIphone,
        'Safari',
      );

      expect(intro, contains('Safari'));
    });

    test('${l10n.localeName} names Chrome for Android installation', () {
      final intro = l10n.profileInstallIntro(
        l10n.profileInstallDeviceAndroid,
        'Chrome',
      );

      expect(intro, contains('Chrome'));
    });
  }
}
