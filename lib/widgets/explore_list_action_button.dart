import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';

/// Quiet circular icon action for Explore list cards (share / locate).
///
/// Recedes into the card: tonal wash + soft outline, no elevation. Keeps a
/// 40px touch target so Spots and Activities stay aligned.
class ExploreListActionButton extends StatelessWidget {
  const ExploreListActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final button = Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: CircleBorder(
        side: BorderSide(
          color: colorScheme.outline.withValues(
            alpha: SpotDetailUi.outlineBorderAlpha,
          ),
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    final tip = tooltip?.trim();
    if (tip == null || tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}
