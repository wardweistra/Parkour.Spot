import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/url_service.dart';
import '../utils/external_launch.dart';

/// "By continuing, you accept our privacy policy." with a tappable link, shown
/// where people sign in or create an account.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final link = l10n.legalPrivacyPolicyLink;
    final sentence = l10n.legalSignInNotice(link);
    final linkStart = sentence.indexOf(link);

    void open() =>
        launchExternalUri(context, Uri.parse(UrlService.aboutPrivacyUrl));

    if (linkStart < 0) {
      return TextButton(onPressed: open, child: Text(sentence));
    }

    return Semantics(
      link: true,
      label: sentence,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: sentence.substring(0, linkStart)),
                TextSpan(
                  text: link,
                  style: TextStyle(
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary,
                  ),
                ),
                TextSpan(text: sentence.substring(linkStart + link.length)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
