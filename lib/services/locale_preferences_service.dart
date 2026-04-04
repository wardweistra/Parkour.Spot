import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parkour_spot/l10n/app_localizations.dart';

/// Persists optional app UI language override in [SharedPreferences].
/// When [locale] is null, [MaterialApp] uses normal device locale resolution.
class LocalePreferencesService extends ChangeNotifier {
  static const String _key = 'app_locale_language_code_override';

  String? _languageCode;

  String? get overrideLanguageCode => _languageCode;

  /// Non-null forces that locale; null follows system resolution.
  Locale? get locale =>
      _languageCode == null ? null : Locale(_languageCode!);

  static List<String> supportedLanguageCodes() {
    return AppLocalizations.supportedLocales
        .map((e) => e.languageCode)
        .toList();
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      final supported = supportedLanguageCodes();
      if (stored != null && supported.contains(stored)) {
        _languageCode = stored;
      } else {
        _languageCode = null;
        if (stored != null) {
          await prefs.remove(_key);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('LocalePreferencesService.loadFromStorage: $e');
    }
  }

  Future<void> setOverride(String languageCode) async {
    if (!supportedLanguageCodes().contains(languageCode)) return;
    _languageCode = languageCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }

  Future<void> clearOverride() async {
    _languageCode = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Autonym labels for the language picker (same in every UI locale).
  static String nativeLanguageLabel(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'nl':
        return 'Nederlands';
      case 'pt':
        return 'Português';
      default:
        return languageCode;
    }
  }
}
