import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared chrome for spot detail quick actions and the community panel.
abstract final class SpotDetailUi {
  static const double surfaceRadius = 12;

  /// Max width of the centered detail content column (spot, event, etc.).
  static const double maxContentWidth = 1200;

  static const double contentHorizontalPadding = 16;

  static const double appBarButtonSize = 40;

  /// Below this width, Edit and Save quick actions use icon-only chips (Material compact).
  static const double quickActionsCompactLayoutMaxWidth = 600;

  /// Horizontal inset so app bar / carousel controls align with [maxContentWidth] content.
  static double contentHorizontalInset(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final centeredGutter = math.max(0.0, (screenWidth - maxContentWidth) / 2);
    return centeredGutter + contentHorizontalPadding;
  }

  /// Single outline treatment so labeled buttons and the community block match.
  static const double outlineBorderAlpha = 0.35;

  static Border outlineBorder(ColorScheme colorScheme) => Border.all(
        width: 1,
        color: colorScheme.outline.withValues(alpha: outlineBorderAlpha),
      );
}
