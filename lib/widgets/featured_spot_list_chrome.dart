import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../services/spot_list_service.dart';
import 'emoji_text.dart';

/// Soft status chip for a featured list (matches spot feature-chip wash).
class FeaturedStatusChip extends StatelessWidget {
  const FeaturedStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.spotListFeaturedTooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Chip(
        avatar: Icon(Icons.star, size: 16, color: scheme.primary),
        label: Text(l10n.spotListFeaturedBadge),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.1),
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        ),
      ),
    );
  }
}

/// Spot-detail callout: featured lists that include this spot.
///
/// Visual family matches [LinkedUpcomingEventPanel]: tonal wash, 12px radius,
/// one heading, tappable rows — no orphan label above the block.
class SpotFeaturedListsSection extends StatelessWidget {
  const SpotFeaturedListsSection({
    super.key,
    required this.spotId,
    this.margin = EdgeInsets.zero,
  });

  final String spotId;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spotListService = context.read<SpotListService>();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<SpotList>>(
      stream: spotListService.watchFeaturedSpotLists(),
      builder: (context, snapshot) {
        final lists = (snapshot.data ?? const <SpotList>[])
            .where((list) => list.effectiveSpotIds.contains(spotId))
            .toList();
        if (lists.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: margin,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.spotOnFeaturedListsTitle,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...lists.map((list) {
                  final id = list.id;
                  return Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: id == null
                          ? null
                          : () => context.push('/list/$id'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: EmojiText(
                                list.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
