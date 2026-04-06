// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get tabExplore => 'Verkennen';

  @override
  String get tabAddSpot => 'Spot toevoegen';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Instellingen';

  @override
  String get profileSettingsLanguageLabel => 'Taal';

  @override
  String get profileSettingsLanguageDescription =>
      'Kies een taal of volg je apparaatinstellingen.';

  @override
  String get profileLanguageSystemDefault => 'Apparaattaal';
}
