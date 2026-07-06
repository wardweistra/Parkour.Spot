import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';

/// One linked item shown in [DetailLinkedDuplicatesSection].
class DetailDuplicateLinkItem {
  const DetailDuplicateLinkItem({
    required this.id,
    required this.title,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
}

/// Prominent callout when the current detail page is marked as a duplicate.
class DetailDuplicateOfCallout extends StatelessWidget {
  const DetailDuplicateOfCallout({
    super.key,
    required this.bannerTitle,
    required this.bannerBody,
    required this.loadingLabel,
    required this.originalFallback,
    required this.loading,
    this.originalTitle,
    this.onOpenOriginal,
  });

  final String bannerTitle;
  final String bannerBody;
  final String loadingLabel;
  final String originalFallback;
  final bool loading;
  final String? originalTitle;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canOpen = !loading && onOpenOriginal != null;
    final displayTitle = loading
        ? loadingLabel
        : (originalTitle?.trim().isNotEmpty == true
              ? originalTitle!.trim()
              : originalFallback);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: SpotDetailUi.detailCardPadding,
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    size: 22,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bannerTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bannerBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onPrimaryContainer.withValues(
                              alpha: 0.9,
                            ),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Material(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius - 2),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canOpen ? onOpenOriginal : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (canOpen)
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visible list of other listings marked as duplicates of the current page.
///
/// Matches spot detail "Also based on" attribution: section heading plus
/// indented rows with source names where available.
class DetailLinkedDuplicatesSection extends StatelessWidget {
  const DetailLinkedDuplicatesSection({
    super.key,
    required this.heading,
    required this.loadingLabel,
    required this.loading,
    required this.items,
    required this.onOpenItem,
  });

  final String heading;
  final String loadingLabel;
  final bool loading;
  final List<DetailDuplicateLinkItem> items;
  final ValueChanged<String> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.secondary;

    return Padding(
      padding: const EdgeInsets.only(top: SpotDetailUi.detailFooterGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            ListTile(
              leading: Icon(Icons.copy_all, color: accent),
              title: Text(heading),
              subtitle: Text(loadingLabel),
              contentPadding: EdgeInsets.zero,
            )
          else ...[
            ListTile(
              leading: Icon(Icons.copy_all, color: accent),
              title: Text(
                heading,
                style: theme.textTheme.titleSmall,
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            ...items.map((item) => _DuplicateSourceRow(
                  item: item,
                  accent: accent,
                  onOpenItem: onOpenItem,
                )),
          ],
        ],
      ),
    );
  }
}

class _DuplicateSourceRow extends StatelessWidget {
  const _DuplicateSourceRow({
    required this.item,
    required this.accent,
    required this.onOpenItem,
  });

  final DetailDuplicateLinkItem item;
  final Color accent;
  final ValueChanged<String> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle?.trim();

    return GestureDetector(
      onTap: () => onOpenItem(item.id),
      child: Padding(
        padding: const EdgeInsets.only(left: 48),
        child: ListTile(
          leading: Icon(
            Icons.arrow_right,
            size: 16,
            color: accent,
          ),
          title: Text(
            item.title,
            style: TextStyle(color: accent),
          ),
          subtitle: subtitle != null && subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: accent.withValues(alpha: 0.7),
                  ),
                )
              : null,
          contentPadding: EdgeInsets.zero,
          trailing: Icon(
            Icons.open_in_new,
            size: 16,
            color: accent,
          ),
        ),
      ),
    );
  }
}
