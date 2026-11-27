import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Share card ground and accent (`functions/lib/year-review-card.js`): the
/// banner opens the card, so it borrows the card's colours.
const Color _cardGround = Color(0xFF13191C);
const Color _cardAccent = Color(0xFF8ECFF2);

/// Profile entry to the yearly review, shown 1 December to 31 January.
///
/// [name] is null on your own profile ("Your 2026 on Parkour·Spot").
class YearReviewBanner extends StatelessWidget {
  const YearReviewBanner({
    super.key,
    required this.year,
    required this.onOpen,
    this.name,
  });

  final int year;
  final String? name;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOwn = name == null;
    final title = isOwn
        ? l10n.yearReviewBannerOwnTitle('$year')
        : l10n.yearReviewBannerOtherTitle(name!, '$year');

    return Semantics(
      button: true,
      label: isOwn ? '$title. ${l10n.yearReviewBannerOwnBody}' : title,
      excludeSemantics: true,
      child: Material(
        color: _cardGround,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isOwn) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.yearReviewBannerOwnBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: _cardAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
