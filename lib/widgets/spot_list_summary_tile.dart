import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../utils/spot_list_localization.dart';
import 'emoji_text.dart';

/// One list in a hub or public profile: name, optional description, visibility
/// and count. Not wrapped in a Card so parents can group with spacing, not nesting.
class SpotListSummaryTile extends StatelessWidget {
  const SpotListSummaryTile({
    super.key,
    required this.list,
    required this.onTap,
    this.leading,
  });

  final SpotList list;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = list.description?.trim();
    final subtitle = list.visibility.localizedVisibilityAndCount(
      l10n,
      list.spotCount,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: leading,
      title: EmojiText(
        list.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
