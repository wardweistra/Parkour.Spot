// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tabExplore => 'Entdecken';

  @override
  String get tabAddSpot => 'Spot hinzufügen';

  @override
  String get tabAccount => 'Konto';

  @override
  String get profileSettingsTitle => 'Einstellungen';

  @override
  String get profileSettingsLanguageLabel => 'Sprache';

  @override
  String get profileSettingsLanguageDescription =>
      'Sprache wählen oder Geräteeinstellung verwenden.';

  @override
  String get profileLanguageSystemDefault => 'Gerätesprache';
}
