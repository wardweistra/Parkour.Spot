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

/// Deemphasized list of items marked as duplicates of the current detail page.
class DetailLinkedDuplicatesSection extends StatefulWidget {
  const DetailLinkedDuplicatesSection({
    super.key,
    required this.heading,
    required this.loadingLabel,
    required this.loading,
    required this.items,
    required this.onOpenItem,
    this.initiallyExpanded = false,
  });

  final String heading;
  final String loadingLabel;
  final bool loading;
  final List<DetailDuplicateLinkItem> items;
  final ValueChanged<String> onOpenItem;
  final bool initiallyExpanded;

  @override
  State<DetailLinkedDuplicatesSection> createState() =>
      _DetailLinkedDuplicatesSectionState();
}

class _DetailLinkedDuplicatesSectionState
    extends State<DetailLinkedDuplicatesSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(DetailLinkedDuplicatesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initiallyExpanded && widget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;
    final headingStyle = theme.textTheme.bodyMedium?.copyWith(
      color: muted,
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.only(top: SpotDetailUi.detailSubsectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.heading,
                        style: headingStyle,
                      ),
                    ),
                  if (widget.loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted.withValues(alpha: 0.65),
                      ),
                    )
                  else
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                      color: muted.withValues(alpha: 0.85),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: SpotDetailUi.detailLabelGap),
                    if (widget.loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          widget.loadingLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      )
                    else
                      ...widget.items.map((item) {
                        final subtitle = item.subtitle?.trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: InkWell(
                            onTap: () => widget.onOpenItem(item.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 18,
                                      color: muted.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: muted,
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: muted
                                                    .withValues(alpha: 0.35),
                                              ),
                                        ),
                                        if (subtitle != null &&
                                            subtitle.isNotEmpty)
                                          Text(
                                            subtitle,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: muted.withValues(
                                                    alpha: 0.75,
                                                  ),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: muted.withValues(alpha: 0.65),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                )
              : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
