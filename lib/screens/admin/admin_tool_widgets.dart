import 'package:flutter/material.dart';

/// Label above a grouped tools card (Admin Tools and Moderator Tools).
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// One card wrapping related admin tool rows.
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class AdminToolTile extends StatelessWidget {
  const AdminToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
    this.badgeCount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget leading = Icon(icon);
    if (badgeCount != null && badgeCount! > 0) {
      leading = Badge(label: Text('$badgeCount'), child: leading);
    }
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : null,
      onTap: onTap,
    );
  }
}
