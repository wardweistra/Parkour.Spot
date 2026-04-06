// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabExplore => 'Explorer';

  @override
  String get tabAddSpot => 'Ajouter un spot';

  @override
  String get tabAccount => 'Compte';

  @override
  String get profileSettingsTitle => 'Réglages';

  @override
  String get profileSettingsLanguageLabel => 'Langue';

  @override
  String get profileSettingsLanguageDescription =>
      'Choisissez une langue ou suivez les réglages de l’appareil.';

  @override
  String get profileLanguageSystemDefault => 'Langue de l’appareil';
}
