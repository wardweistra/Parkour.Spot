import 'package:flutter/material.dart';

/// Shared chrome for spot detail quick actions and the community panel.
abstract final class SpotDetailUi {
  static const double surfaceRadius = 12;

  /// Below this width, Edit and Save quick actions use icon-only chips (Material compact).
  static const double quickActionsCompactLayoutMaxWidth = 600;

  /// Single outline treatment so labeled buttons and the community block match.
  static const double outlineBorderAlpha = 0.35;

  static Border outlineBorder(ColorScheme colorScheme) => Border.all(
        width: 1,
        color: colorScheme.outline.withValues(alpha: outlineBorderAlpha),
      );
}
