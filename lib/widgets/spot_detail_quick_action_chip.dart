import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';

/// Outlined chip with icon + short label for Save / Edit / Share quick actions.
/// Used on spot detail and spot list detail so the action row reads as one family.
class SpotDetailQuickActionChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  /// When non-null, shown instead of [label] (e.g. mixed text styles).
  final Widget? labelWidget;
  final bool showSpinner;

  const SpotDetailQuickActionChip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelWidget,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          border: SpotDetailUi.outlineBorder(cs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            else
              Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            labelWidget != null
                ? DefaultTextStyle(
                    style: theme.textTheme.labelLarge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: labelWidget!,
                  )
                : Text(
                    label,
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ],
        ),
      ),
    );
  }
}
