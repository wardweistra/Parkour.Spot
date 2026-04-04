// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabAddSpot => 'Adicionar spot';

  @override
  String get tabAccount => 'Conta';

  @override
  String get profileSettingsTitle => 'Definições';

  @override
  String get profileSettingsLanguageLabel => 'Idioma';

  @override
  String get profileSettingsLanguageDescription =>
      'Escolha um idioma ou use o do dispositivo.';

  @override
  String get profileLanguageSystemDefault => 'Idioma do dispositivo';
}
