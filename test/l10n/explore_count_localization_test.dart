import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations_fr.dart';

void main() {
  test('French explore spot count preserves zero', () {
    final l10n = AppLocalizationsFr();

    expect(l10n.exploreSpotCountShort(0), '0 spot');
    expect(l10n.exploreSpotCountShort(1), '1 spot');
    expect(l10n.exploreSpotCountShort(2), '2 spots');
  });
}
