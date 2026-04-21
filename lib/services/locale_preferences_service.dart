import 'package:flutter/material.dart';

import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/services/auth_service.dart';

/// Resolves app UI language from authenticated user profile preferences.
class LocalePreferencesService extends ChangeNotifier {
  LocalePreferencesService(this._authService) {
    _authService.addListener(_onAuthChanged);
  }

  final AuthService _authService;

  String? get _profileLanguageCode =>
      _authService.userProfile?.preferredLanguageCode;

  bool get _isExplicitlySet =>
      _authService.userProfile?.isLanguageExplicitlySet == true;

  String? get overrideLanguageCode {
    if (!_isExplicitlySet) return null;
    return _profileLanguageCode;
  }

  /// Non-null forces that locale; null follows system resolution.
  Locale? get locale {
    final code = _profileLanguageCode;
    if (code == null || code.isEmpty) return null;
    final normalized = code.trim().toLowerCase();
    if (supportedLanguageCodes().contains(normalized)) {
      return Locale(normalized);
    }
    return const Locale('en');
  }

  static List<String> supportedLanguageCodes() {
    return AppLocalizations.supportedLocales
        .map((e) => e.languageCode)
        .toList();
  }

  Future<void> loadFromStorage() async {}

  Future<void> setOverride(String languageCode) async {
    if (!supportedLanguageCodes().contains(languageCode)) return;
    await _authService.updatePreferredLanguageExplicit(languageCode);
  }

  Future<void> clearOverride() async {
    await _authService.resetPreferredLanguageToBrowserDefault();
  }

  void _onAuthChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
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
