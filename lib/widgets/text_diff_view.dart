import 'package:flutter/material.dart';

import '../utils/text_diff.dart';

/// Git-style unified diff of [before] and [after].
///
/// Shared by duplicate-change review and edit-suggestion review.
class TextDiffView extends StatelessWidget {
  const TextDiffView({
    super.key,
    required this.before,
    required this.after,
    this.valueStyle,
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
