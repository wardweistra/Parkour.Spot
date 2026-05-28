import 'package:flutter/material.dart';

/// Icon, title, and optional subtitle row for detail-screen popup menus.
class DetailActionMenuItem extends StatelessWidget {
  const DetailActionMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool enabled;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ?? (enabled ? theme.colorScheme.primary : disabled),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: titleColor ?? (enabled ? null : disabled),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
