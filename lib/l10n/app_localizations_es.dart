// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabAddSpot => 'Añadir spot';

  @override
  String get tabAccount => 'Cuenta';

  @override
  String get profileSettingsTitle => 'Ajustes';

  @override
  String get profileSettingsLanguageLabel => 'Idioma';

  @override
  String get profileSettingsLanguageDescription =>
      'Elige un idioma o usa el de tu dispositivo.';

  @override
  String get profileLanguageSystemDefault => 'Idioma del dispositivo';
}
