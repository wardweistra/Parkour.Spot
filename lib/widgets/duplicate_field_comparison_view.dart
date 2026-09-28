import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/duplicate_field_comparison.dart';
import '../utils/text_diff.dart';

/// External previous-to-current change, the native value, and whether that
/// native value still matches the previous external value.
class DuplicateFieldComparisonView extends StatelessWidget {
  const DuplicateFieldComparisonView({
    super.key,
    required this.comparison,
    required this.nativeLabel,
    required this.nativeUnavailableLabel,
  });

  final DuplicateFieldComparison comparison;
  final String nativeLabel;
  final String nativeUnavailableLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final subLabelStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurface,
      height: 1.35,
    );
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      height: 1.35,
    );
    final matches = comparison.nativeMatchesPrevious;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.duplicateChangesExternal, style: labelStyle),
          const SizedBox(height: 2),
          if (comparison.previousUnavailable) ...[
            Text(comparison.currentSummary, style: valueStyle),
            const SizedBox(height: 2),
            Text(l10n.duplicateChangesPreviousUnavailable, style: noteStyle),
          ] else
            ..._externalLines(
              lines: comparison.lines,
              valueStyle: valueStyle,
              subLabelStyle: subLabelStyle,
              noteStyle: noteStyle,
              contentsChangedLabel: l10n.duplicateChangesContentsChanged,
            ),
          const SizedBox(height: 10),
          Text(nativeLabel, style: labelStyle),
          if (comparison.nativeUnavailable) ...[
            const SizedBox(height: 2),
            Text(nativeUnavailableLabel, style: noteStyle),
          ] else if (matches != true) ...[
            const SizedBox(height: 2),
            if (comparison.previousUnavailable)
              Text(comparison.nativeSummary ?? '', style: valueStyle)
            else
              ..._nativeLines(
                lines: comparison.lines,
                valueStyle: valueStyle,
                subLabelStyle: subLabelStyle,
              ),
          ],
          if (matches != null) ...[
            const SizedBox(height: 2),
            Text(
              matches
                  ? l10n.duplicateChangesSameAsPrevious
                  : l10n.duplicateChangesDiffersFromPrevious,
              style: noteStyle?.copyWith(
                color: matches ? colors.onSurfaceVariant : colors.tertiary,
                fontWeight: matches ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _externalLines({
    required List<DuplicateChangeLine> lines,
    required TextStyle? valueStyle,
    required TextStyle? subLabelStyle,
    required TextStyle? noteStyle,
    required String contentsChangedLabel,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) widgets.add(const SizedBox(height: 6));
      final label = line.label;
      if (label != null) {
        widgets.add(Text(label, style: subLabelStyle));
        widgets.add(const SizedBox(height: 2));
      }
      widgets.add(
        _DiffBlock(before: line.from, after: line.to, valueStyle: valueStyle),
      );
      if (line.contentsChanged) {
        widgets.add(const SizedBox(height: 2));
        widgets.add(Text(contentsChangedLabel, style: noteStyle));
      }
    }
    return widgets;
  }

  List<Widget> _nativeLines({
    required List<DuplicateChangeLine> lines,
    required TextStyle? valueStyle,
    required TextStyle? subLabelStyle,
  }) {
    final widgets = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) widgets.add(const SizedBox(height: 6));
      final label = line.label;
      if (label != null) {
        widgets.add(Text(label, style: subLabelStyle));
        widgets.add(const SizedBox(height: 2));
      }
      widgets.add(Text(line.native, style: valueStyle));
    }
    return widgets;
  }
}

class _DiffColors {
  const _DiffColors({
    required this.removeBackground,
    required this.removeForeground,
    required this.addBackground,
    required this.addForeground,
  });

  final Color removeBackground;
  final Color removeForeground;
  final Color addBackground;
  final Color addForeground;

  factory _DiffColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    if (dark) {
      return const _DiffColors(
        removeBackground: Color(0xFF3F1D20),
        removeForeground: Color(0xFFFFB4AB),
        addBackground: Color(0xFF0D2B16),
        addForeground: Color(0xFF7EE787),
      );
    }
    return const _DiffColors(
      removeBackground: Color(0xFFFFEBE9),
      removeForeground: Color(0xFF82071E),
      addBackground: Color(0xFFDAFBE1),
      addForeground: Color(0xFF116329),
    );
  }
}

class _DiffBlock extends StatelessWidget {
  const _DiffBlock({
    required this.before,
    required this.after,
    required this.valueStyle,
  });

  final String before;
  final String after;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _DiffColors.of(theme);
    final rows = diffText(before, after);
    final base = valueStyle ?? theme.textTheme.bodyMedium;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            _DiffLine(row: row, base: base, colors: colors),
        ],
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({
    required this.row,
    required this.base,
    required this.colors,
  });

  final TextDiffRow row;
  final TextStyle? base;
  final _DiffColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final op = row.op;
    final isDelete = op == TextDiffOp.delete;
    final isInsert = op == TextDiffOp.insert;
    final background = isDelete
        ? colors.removeBackground
        : isInsert
        ? colors.addBackground
        : Colors.transparent;
    final gutter = isDelete
        ? '−'
        : isInsert
        ? '+'
        : '';
    final gutterColor = isDelete
        ? colors.removeForeground
        : colors.addForeground;
    final style = (base ?? const TextStyle()).copyWith(color: onSurface);
    final blank = row.text.isEmpty;
    final blankMarker = isDelete || isInsert ? '↵' : ' ';

    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child: Text(
                gutter,
                style: style.copyWith(
                  color: gutterColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: blank
                  ? Text(blankMarker, style: style.copyWith(color: gutterColor))
                  : Text.rich(
                      TextSpan(
                        style: style,
                        children: [
                          for (final span in row.spans)
                            TextSpan(
                              text: visibleDiffSpanText(span),
                              style: _spanStyle(span, style),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _spanStyle(TextDiffSpan span, TextStyle style) {
    if (row.op == TextDiffOp.delete && span.op == TextDiffOp.delete) {
      return style.copyWith(
        color: colors.removeForeground,
        decoration: TextDecoration.lineThrough,
        decorationColor: colors.removeForeground,
        fontWeight: FontWeight.w600,
      );
    }
    if (row.op == TextDiffOp.insert && span.op == TextDiffOp.insert) {
      return style.copyWith(
        color: colors.addForeground,
        fontWeight: FontWeight.w700,
      );
    }
    return style;
  }
}
