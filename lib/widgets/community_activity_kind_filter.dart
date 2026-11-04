import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/community_activity_lens.dart';

/// Compact kind-lens control for the Explore activities stream.
///
/// Closed: filter icon only on All; icon + active lens name otherwise.
/// Open: anchored popup with All / Events / Sessions / Contributions.
class CommunityActivityKindFilter extends StatelessWidget {
  const CommunityActivityKindFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CommunityActivityLens value;
  final ValueChanged<CommunityActivityLens> onChanged;

  static const Key buttonKey = ValueKey('community-lens-button');
  static const Key chipKeyAll = ValueKey('community-lens-all');
  static const Key chipKeyEvents = ValueKey('community-lens-events');
  static const Key chipKeySessions = ValueKey('community-lens-sessions');
  static const Key chipKeyContributions = ValueKey(
    'community-lens-contributions',
  );

  String _labelFor(CommunityActivityLens lens, AppLocalizations l10n) {
    return switch (lens) {
      CommunityActivityLens.all => l10n.communityStreamFilterAll,
      CommunityActivityLens.events => l10n.communityStreamFilterEvents,
      CommunityActivityLens.sessions => l10n.communityStreamFilterSessions,
      CommunityActivityLens.contributions =>
        l10n.communityStreamFilterContributions,
    };
  }

  Key _keyFor(CommunityActivityLens lens) {
    return switch (lens) {
      CommunityActivityLens.all => chipKeyAll,
      CommunityActivityLens.events => chipKeyEvents,
      CommunityActivityLens.sessions => chipKeySessions,
      CommunityActivityLens.contributions => chipKeyContributions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showLensName = value != CommunityActivityLens.all;
    final activeLabel = _labelFor(value, l10n);
    final muted = scheme.onSurface.withValues(alpha: 0.65);

    final options = CommunityActivityLens.values;

    return PopupMenuButton<CommunityActivityLens>(
      key: buttonKey,
      tooltip: l10n.communityStreamFilterTooltip,
      initialValue: value,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 4),
      onSelected: (lens) {
        if (lens != value) onChanged(lens);
      },
      itemBuilder: (context) {
        return [
          for (final lens in options)
            CheckedPopupMenuItem<CommunityActivityLens>(
              key: _keyFor(lens),
              value: lens,
              checked: lens == value,
              child: Text(_labelFor(lens, l10n)),
            ),
        ];
      },
      child: Semantics(
        button: true,
        label: showLensName
            ? '${l10n.communityStreamFilterTooltip}: $activeLabel'
            : l10n.communityStreamFilterTooltip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showLensName ? 8 : 6,
              vertical: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  size: 18,
                  color: showLensName ? scheme.primary : muted,
                ),
                if (showLensName) ...[
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      activeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
