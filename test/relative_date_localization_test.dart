import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations_en.dart';
import 'package:parkour_spot/l10n/app_localizations_nl.dart';
import 'package:parkour_spot/utils/relative_date_localization.dart';

void main() {
  group('formatRelativeDateInDays', () {
    final now = DateTime(2026, 4, 10, 12);

    test('returns localized today and yesterday labels', () {
      final en = AppLocalizationsEn();
      final nl = AppLocalizationsNl();

      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 10, 8), en, now: now),
        'today',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 9, 23), en, now: now),
        'yesterday',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 10, 8), nl, now: now),
        'vandaag',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 9, 23), nl, now: now),
        'gisteren',
      );
    });

    test('returns localized pluralized durations', () {
      final en = AppLocalizationsEn();
      final nl = AppLocalizationsNl();

      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 8), en, now: now),
        '2 days ago',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 3, 11), en, now: now),
        '1 month ago',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 3, 11), nl, now: now),
        '1 maand geleden',
      );
    });

    test('returns localized future day phrases', () {
      final en = AppLocalizationsEn();
      final nl = AppLocalizationsNl();

      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 11), en, now: now),
        'tomorrow',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 13), en, now: now),
        'in 3 days',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 24), en, now: now),
        'in 2 weeks',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 11), nl, now: now),
        'morgen',
      );
      expect(
        formatRelativeDateInDays(DateTime(2026, 4, 13), nl, now: now),
        'over 3 dagen',
      );
    });
  });
}
