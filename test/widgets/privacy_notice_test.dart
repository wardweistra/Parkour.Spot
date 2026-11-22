import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/privacy_notice.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.languageCode}: notice contains the link text', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final link = l10n.legalPrivacyPolicyLink;
      expect(l10n.legalSignInNotice(link), contains(link));
    });
  }

  testWidgets('renders the sentence with the link as one tappable target', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: PrivacyNotice()),
      ),
    );

    final sentence = l10n.legalSignInNotice(l10n.legalPrivacyPolicyLink);
    expect(find.text(sentence, findRichText: true), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
  });
}
