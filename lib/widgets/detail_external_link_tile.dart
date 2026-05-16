import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';
import '../services/url_service.dart';

/// Tappable external link on detail pages — domain is the primary label.
class DetailExternalLinkTile extends StatelessWidget {
  const DetailExternalLinkTile({
    super.key,
    required this.url,
    required this.caption,
    required this.openSemanticsLabel,
  });

  final String url;
  final String caption;
  final String openSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hostLabel = UrlService.displayHttpUrlHost(url);

    return Semantics(
      button: true,
      label: openSemanticsLabel,
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        child: InkWell(
          onTap: () => UrlService.openHttpOrHttpsUrl(url, context),
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          child: Container(
            width: double.infinity,
            padding: SpotDetailUi.detailCardPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.language_outlined, color: colors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hostLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 20,
                  color: colors.primary.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
