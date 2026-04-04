// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabAddSpot => 'Add Spot';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSettingsLanguageLabel => 'Language';

  @override
  String get profileSettingsLanguageDescription =>
      'Choose a language or follow your device settings.';

  @override
  String get profileLanguageSystemDefault => 'Device language';
}
