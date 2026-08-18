import 'package:flutter/material.dart';

/// Tinted note callout used on published list cards and in list edit rows.
class SpotListNoteBlock extends StatelessWidget {
  const SpotListNoteBlock({
    super.key,
    required this.child,
    this.icon = Icons.sticky_note_2_outlined,
    this.actions = const [],
    this.onTap,
    this.muted = false,
  });

  final Widget child;
  final IconData icon;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool muted;

  static const double radius = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = muted
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.7);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: child,
            ),
          ),
          if (actions.isNotEmpty) ...actions,
        ],
      ),
    );

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(radius),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: content,
            ),
    );
  }
}
