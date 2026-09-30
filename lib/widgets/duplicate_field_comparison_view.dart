import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/duplicate_field_comparison.dart';
import 'text_diff_view.dart';

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
        TextDiffView(before: line.from, after: line.to, valueStyle: valueStyle),
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
