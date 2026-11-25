import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/user_contribution_stats.dart';
import 'custom_button.dart';

/// One counted kind of contribution on the profile.
enum ContributionKind {
  spotsAdded,
  spotsImproved,
  photosAdded,
  eventsCreated,
  eventsImproved,
  checkIns,
  trainingPlans,
  ratings,
  lists,
}

/// What a group of contributions did for others.
enum ContributionGroupKind { map, people, guide }

class ContributionRow {
  const ContributionRow(this.kind, this.count);

  final ContributionKind kind;
  final int count;
}

class ContributionGroup {
  const ContributionGroup(this.kind, this.rows);

  final ContributionGroupKind kind;
  final List<ContributionRow> rows;
}

/// Groups with at least one non-zero row, in display order. Zero rows and
/// empty groups are dropped, so a sparse profile never shows a wall of zeros.
List<ContributionGroup> buildContributionGroups(UserContributionStats stats) {
  ContributionGroup? group(
    ContributionGroupKind kind,
    List<ContributionRow> rows,
  ) {
    final nonZero = rows.where((row) => row.count > 0).toList();
    return nonZero.isEmpty ? null : ContributionGroup(kind, nonZero);
  }

  return [
    group(ContributionGroupKind.map, [
      ContributionRow(ContributionKind.spotsAdded, stats.spotsAdded),
      ContributionRow(ContributionKind.spotsImproved, stats.spotsImproved),
      ContributionRow(ContributionKind.photosAdded, stats.photosAdded),
    ]),
    group(ContributionGroupKind.people, [
      ContributionRow(ContributionKind.eventsCreated, stats.eventsCreated),
      ContributionRow(ContributionKind.eventsImproved, stats.eventsImproved),
      ContributionRow(ContributionKind.checkIns, stats.checkIns),
      ContributionRow(ContributionKind.trainingPlans, stats.trainingPlans),
    ]),
    group(ContributionGroupKind.guide, [
      ContributionRow(ContributionKind.ratings, stats.ratings),
      ContributionRow(ContributionKind.lists, stats.lists),
    ]),
  ].whereType<ContributionGroup>().toList();
}

/// Contributions card on the public profile.
///
/// Shows only the kinds a person actually contributed. With no contributions
/// it renders nothing on someone else's profile, and an invitation to add a
/// first spot on your own.
class ProfileContributionsSection extends StatelessWidget {
  const ProfileContributionsSection({
    super.key,
    required this.stats,
    required this.isOwnProfile,
    this.onOpenRow,
    this.onAddSpot,
  });

  final UserContributionStats stats;
  final bool isOwnProfile;

  /// Returns the action for a row that links to its items, or null when the
  /// row is not a link (e.g. the list is not public).
  final VoidCallback? Function(ContributionKind kind)? onOpenRow;

  /// Opens Add spot from the empty state on your own profile.
  final VoidCallback? onAddSpot;

  static const double _wideGroupMinWidth = 220;
  static const double _groupGap = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final groups = buildContributionGroups(stats);

    if (groups.isEmpty) {
      if (!isOwnProfile) return const SizedBox.shrink();
      return _EmptyContributions(onAddSpot: onAddSpot);
    }

    final numberStyle = contributionNumberStyle(theme);
    // One count column for the whole section, sized to the widest count, so
    // labels share a left edge across stacked groups whether a count is 3 or
    // 271.
    // Measure every count: Fredoka's digits are not equal width, so "23" can
    // be wider than "11" even with tabular figures requested.
    var numberWidth = 0.0;
    for (final row in groups.expand((group) => group.rows)) {
      final painter = TextPainter(
        text: TextSpan(text: '${row.count}', style: numberStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > numberWidth) numberWidth = painter.width;
      painter.dispose();
    }
    numberWidth = numberWidth.ceilToDouble() + 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileContributionsTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // All groups side by side when they fit, otherwise stacked:
                // a 2 + 1 grid leaves an orphan that reads as missing data.
                final fitsInOneRow =
                    groups.length * _wideGroupMinWidth +
                        _groupGap * (groups.length - 1) <=
                    constraints.maxWidth;
                final columns = fitsInOneRow ? groups.length : 1;
                // Floor so rounding never pushes the last group to a new run.
                final groupWidth =
                    ((constraints.maxWidth - _groupGap * (columns - 1)) /
                            columns)
                        .floorToDouble();
                return Wrap(
                  spacing: _groupGap,
                  runSpacing: 20,
                  children: [
                    for (final group in groups)
                      SizedBox(
                        width: groupWidth,
                        child: _ContributionGroupView(
                          group: group,
                          numberStyle: numberStyle,
                          numberWidth: numberWidth,
                          onOpenRow: onOpenRow,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Count style shared by every row (tabular, so digits keep their width).
TextStyle? contributionNumberStyle(ThemeData theme) =>
    theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class _ContributionGroupView extends StatelessWidget {
  const _ContributionGroupView({
    required this.group,
    required this.numberStyle,
    required this.numberWidth,
    this.onOpenRow,
  });

  final ContributionGroup group;
  final TextStyle? numberStyle;
  final double numberWidth;
  final VoidCallback? Function(ContributionKind kind)? onOpenRow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(_groupIcon(group.kind), size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _groupTitle(l10n, group.kind),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final row in group.rows)
          _ContributionRowView(
            row: row,
            label: _rowLabel(l10n, row),
            numberStyle: numberStyle,
            numberWidth: numberWidth,
            onTap: onOpenRow?.call(row.kind),
          ),
      ],
    );
  }

  static IconData _groupIcon(ContributionGroupKind kind) {
    switch (kind) {
      case ContributionGroupKind.map:
        return Icons.add_location_alt_outlined;
      case ContributionGroupKind.people:
        return Icons.groups_outlined;
      case ContributionGroupKind.guide:
        return Icons.star_outline_rounded;
    }
  }

  static String _groupTitle(AppLocalizations l10n, ContributionGroupKind kind) {
    switch (kind) {
      case ContributionGroupKind.map:
        return l10n.profileContributionsGroupMap;
      case ContributionGroupKind.people:
        return l10n.profileContributionsGroupPeople;
      case ContributionGroupKind.guide:
        return l10n.profileContributionsGroupGuide;
    }
  }

  static String _rowLabel(AppLocalizations l10n, ContributionRow row) {
    switch (row.kind) {
      case ContributionKind.spotsAdded:
        return l10n.profileContributionsSpotsAdded(row.count);
      case ContributionKind.spotsImproved:
        return l10n.profileContributionsSpotsImproved(row.count);
      case ContributionKind.photosAdded:
        return l10n.profileContributionsPhotosAdded(row.count);
      case ContributionKind.eventsCreated:
        return l10n.profileContributionsEventsCreated(row.count);
      case ContributionKind.eventsImproved:
        return l10n.profileContributionsEventsImproved(row.count);
      case ContributionKind.checkIns:
        return l10n.profileContributionsCheckIns(row.count);
      case ContributionKind.trainingPlans:
        return l10n.profileContributionsTrainingPlans(row.count);
      case ContributionKind.ratings:
        return l10n.profileContributionsRatings(row.count);
      case ContributionKind.lists:
        return l10n.profileContributionsLists(row.count);
    }
  }
}

class _ContributionRowView extends StatelessWidget {
  const _ContributionRowView({
    required this.row,
    required this.label,
    required this.numberStyle,
    required this.numberWidth,
    this.onTap,
  });

  final ContributionRow row;
  final String label;
  final TextStyle? numberStyle;
  final double numberWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
    );
    // One row height for plain and linked rows, so the rhythm never jumps;
    // 40px meets the compact-control target in DESIGN.md.
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: numberWidth,
              child: Text(
                '${row.count}',
                textAlign: TextAlign.end,
                style: numberStyle,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              // The chevron rides inline after the label: attached to the
              // words it links, centred on them, and wrapping with them in
              // long translations.
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (onTap != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                style: labelStyle,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: '${row.count} $label',
        excludeSemantics: true,
        child: content,
      );
    }
    // The tap target hugs the row's content, so hover and ripple mark the
    // link itself rather than the whole column.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: '${row.count} $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      ),
    );
  }
}

class _EmptyContributions extends StatelessWidget {
  const _EmptyContributions({this.onAddSpot});

  final VoidCallback? onAddSpot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Full column width and the same 16px inset as the populated card and the
    // lists card, so the empty state sits in the page's grid instead of
    // shrinking to its text.
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: _emptyContent(l10n, theme, colorScheme),
        ),
      ),
    );
  }

  Widget _emptyContent(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileContributionsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(
          l10n.profileContributionsEmptyTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            l10n.profileContributionsEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
        if (onAddSpot != null) ...[
          const SizedBox(height: 16),
          CustomButton(
            onPressed: onAddSpot,
            text: l10n.profileContributionsEmptyAction,
            icon: Icons.add_location_alt_outlined,
            isOutlined: true,
          ),
        ],
      ],
    );
  }
}

/// Placeholder with the section's shape while stats load.
class ProfileContributionsSkeleton extends StatelessWidget {
  const ProfileContributionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(140, 22),
            const SizedBox(height: 20),
            bar(120, 14),
            const SizedBox(height: 14),
            bar(180, 22),
            const SizedBox(height: 14),
            bar(160, 22),
          ],
        ),
      ),
    );
  }
}
