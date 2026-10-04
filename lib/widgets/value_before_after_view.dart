import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Current vs suggested values for edit-suggestion review (non-prose fields).
///
/// Use [TextDiffView] for title and description; this widget is for scalars,
/// lists, and other structured values.
class ValueBeforeAfterView extends StatelessWidget {
  const ValueBeforeAfterView({
    super.key,
    this.before,
    this.after,
    this.beforeLines,
    this.afterLines,
    this.valueStyle,
    this.stackBreakpoint = 420,
  });

  final String? before;
  final String? after;
  final List<String>? beforeLines;
  final List<String>? afterLines;
  final TextStyle? valueStyle;
  final double stackBreakpoint;

  factory ValueBeforeAfterView.fromLines({
    Key? key,
    required List<String> beforeLines,
    required List<String> afterLines,
    TextStyle? valueStyle,
    double stackBreakpoint = 420,
  }) {
    return ValueBeforeAfterView(
      key: key,
      beforeLines: beforeLines,
      afterLines: afterLines,
      valueStyle: valueStyle,
      stackBreakpoint: stackBreakpoint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = _BeforeAfterColors.of(theme);
    final base = valueStyle ?? theme.textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < stackBreakpoint;
        final currentPanel = _ValuePanel(
          label: l10n.locationReviewCurrentLabel,
          lines: _resolvedLines(before, beforeLines),
          valueStyle: base,
          background: colors.currentBackground,
          border: colors.currentBorder,
          labelColor: colors.currentLabel,
        );
        final suggestedPanel = _ValuePanel(
          label: l10n.locationReviewSuggestedLabel,
          lines: _resolvedLines(after, afterLines),
          valueStyle: base,
          background: colors.suggestedBackground,
          border: colors.suggestedBorder,
          labelColor: colors.suggestedLabel,
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              currentPanel,
              const SizedBox(height: 8),
              suggestedPanel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: currentPanel),
            const SizedBox(width: 8),
            Expanded(child: suggestedPanel),
          ],
        );
      },
    );
  }

  static List<String> _resolvedLines(String? text, List<String>? lines) {
    if (lines != null && lines.isNotEmpty) {
      return lines;
    }
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return const <String>[''];
    }
    return value.split('\n');
  }
}

/// Side-by-side chip lists highlighting added and removed labels.
class ListLabelChangeView extends StatelessWidget {
  const ListLabelChangeView({
    super.key,
    required this.beforeLabels,
    required this.afterLabels,
    this.stackBreakpoint = 420,
  });

  final List<String> beforeLabels;
  final List<String> afterLabels;
  final double stackBreakpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _BeforeAfterColors.of(theme);
    final l10n = AppLocalizations.of(context)!;
    final beforeSet = beforeLabels.toSet();
    final afterSet = afterLabels.toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < stackBreakpoint;
        final currentPanel = _ChipPanel(
          label: l10n.locationReviewCurrentLabel,
          labels: beforeLabels,
          background: colors.currentBackground,
          border: colors.currentBorder,
          labelColor: colors.currentLabel,
          chipStyleFor: (label) {
            if (!afterSet.contains(label)) {
              return _ChipStyle.removed(colors);
            }
            return _ChipStyle.neutral(theme);
          },
        );
        final suggestedPanel = _ChipPanel(
          label: l10n.locationReviewSuggestedLabel,
          labels: afterLabels,
          background: colors.suggestedBackground,
          border: colors.suggestedBorder,
          labelColor: colors.suggestedLabel,
          chipStyleFor: (label) {
            if (!beforeSet.contains(label)) {
              return _ChipStyle.added(colors);
            }
            return _ChipStyle.neutral(theme);
          },
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              currentPanel,
              const SizedBox(height: 8),
              suggestedPanel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: currentPanel),
            const SizedBox(width: 8),
            Expanded(child: suggestedPanel),
          ],
        );
      },
    );
  }
}

class _BeforeAfterColors {
  const _BeforeAfterColors({
    required this.currentBackground,
    required this.currentBorder,
    required this.currentLabel,
    required this.suggestedBackground,
    required this.suggestedBorder,
    required this.suggestedLabel,
    required this.removedForeground,
    required this.removedBackground,
    required this.addedForeground,
    required this.addedBackground,
  });

  final Color currentBackground;
  final Color currentBorder;
  final Color currentLabel;
  final Color suggestedBackground;
  final Color suggestedBorder;
  final Color suggestedLabel;
  final Color removedForeground;
  final Color removedBackground;
  final Color addedForeground;
  final Color addedBackground;

  factory _BeforeAfterColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    if (dark) {
      return const _BeforeAfterColors(
        currentBackground: Color(0xFF2A2A2E),
        currentBorder: Color(0xFF5C5C62),
        currentLabel: Color(0xFFB0B0B5),
        suggestedBackground: Color(0xFF0D2B16),
        suggestedBorder: Color(0xFF238636),
        suggestedLabel: Color(0xFF7EE787),
        removedForeground: Color(0xFFFFB4AB),
        removedBackground: Color(0xFF3F1D20),
        addedForeground: Color(0xFF7EE787),
        addedBackground: Color(0xFF0D2B16),
      );
    }
    return const _BeforeAfterColors(
      currentBackground: Color(0xFFF6F8FA),
      currentBorder: Color(0xFFD0D7DE),
      currentLabel: Color(0xFF57606A),
      suggestedBackground: Color(0xFFDAFBE1),
      suggestedBorder: Color(0xFF4AC26B),
      suggestedLabel: Color(0xFF116329),
      removedForeground: Color(0xFF82071E),
      removedBackground: Color(0xFFFFEBE9),
      addedForeground: Color(0xFF116329),
      addedBackground: Color(0xFFDAFBE1),
    );
  }
}

class _ValuePanel extends StatelessWidget {
  const _ValuePanel({
    required this.label,
    required this.lines,
    required this.valueStyle,
    required this.background,
    required this.border,
    required this.labelColor,
  });

  final String label;
  final List<String> lines;
  final TextStyle? valueStyle;
  final Color background;
  final Color border;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final body = valueStyle ?? theme.textTheme.bodyMedium;
    final isMultiLine = lines.length > 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            if (isMultiLine)
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: body?.copyWith(color: onSurface)),
                      Expanded(
                        child: SelectableText(
                          line.isEmpty ? ' ' : line,
                          style: body?.copyWith(color: onSurface, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SelectableText(
                lines.first.isEmpty ? ' ' : lines.first,
                style: body?.copyWith(color: onSurface, height: 1.35),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipStyle {
  const _ChipStyle({
    required this.background,
    required this.foreground,
    this.decoration,
  });

  final Color background;
  final Color foreground;
  final TextDecoration? decoration;

  factory _ChipStyle.neutral(ThemeData theme) {
    return _ChipStyle(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurface,
    );
  }

  factory _ChipStyle.removed(_BeforeAfterColors colors) {
    return _ChipStyle(
      background: colors.removedBackground,
      foreground: colors.removedForeground,
      decoration: TextDecoration.lineThrough,
    );
  }

  factory _ChipStyle.added(_BeforeAfterColors colors) {
    return _ChipStyle(
      background: colors.addedBackground,
      foreground: colors.addedForeground,
    );
  }
}

class _ChipPanel extends StatelessWidget {
  const _ChipPanel({
    required this.label,
    required this.labels,
    required this.background,
    required this.border,
    required this.labelColor,
    required this.chipStyleFor,
  });

  final String label;
  final List<String> labels;
  final Color background;
  final Color border;
  final Color labelColor;
  final _ChipStyle Function(String label) chipStyleFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final empty = l10n.eventDuplicateChangesNoValue;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            if (labels.isEmpty)
              Text(
                empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in labels)
                    _styledChip(context, item, chipStyleFor(item)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _styledChip(BuildContext context, String text, _ChipStyle style) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: style.foreground,
            decoration: style.decoration,
            decorationColor: style.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
