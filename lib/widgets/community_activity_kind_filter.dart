import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/community_activity_lens.dart';

/// Subtle single-select kind lens for the Explore activities stream.
class CommunityActivityKindFilter extends StatelessWidget {
  const CommunityActivityKindFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CommunityActivityLens value;
  final ValueChanged<CommunityActivityLens> onChanged;

  static const Key chipKeyAll = ValueKey('community-lens-all');
  static const Key chipKeyEvents = ValueKey('community-lens-events');
  static const Key chipKeySessions = ValueKey('community-lens-sessions');
  static const Key chipKeyContributions = ValueKey(
    'community-lens-contributions',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final options = <({CommunityActivityLens lens, String label, Key key})>[
      (
        lens: CommunityActivityLens.all,
        label: l10n.communityStreamFilterAll,
        key: chipKeyAll,
      ),
      (
        lens: CommunityActivityLens.events,
        label: l10n.communityStreamFilterEvents,
        key: chipKeyEvents,
      ),
      (
        lens: CommunityActivityLens.sessions,
        label: l10n.communityStreamFilterSessions,
        key: chipKeySessions,
      ),
      (
        lens: CommunityActivityLens.contributions,
        label: l10n.communityStreamFilterContributions,
        key: chipKeyContributions,
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.lens == value;
          return Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: ChoiceChip(
                key: option.key,
                label: Text(option.label),
                selected: selected,
                showCheckmark: false,
                selectedColor: scheme.primaryContainer,
                labelStyle: TextStyle(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (isSelected) {
                  if (isSelected) onChanged(option.lens);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
