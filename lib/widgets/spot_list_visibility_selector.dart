import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../utils/spot_list_localization.dart';

class SpotListVisibilitySelector extends StatelessWidget {
  const SpotListVisibilitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final SpotListVisibility value;
  final ValueChanged<SpotListVisibility> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final helpStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              for (final visibility in SpotListVisibility.values)
                Expanded(
                  child: _VisibilityOption(
                    visibility: visibility,
                    selected: value == visibility,
                    enabled: enabled,
                    onTap: () => onChanged(visibility),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            for (final visibility in SpotListVisibility.values)
              ExcludeSemantics(
                excluding: visibility != value,
                child: Opacity(
                  opacity: visibility == value ? 1 : 0,
                  child: Text(
                    visibility.localizedHelp(l10n),
                    style: helpStyle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.visibility,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SpotListVisibility visibility;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = _chipColors(context, visibility, selected);

    return Tooltip(
      message: visibility.localizedHelp(l10n),
      child: InkWell(
        onTap: enabled && !selected ? onTap : null,
        child: Ink(
          color: colors.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(visibility.icon, size: 16, color: colors.foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    visibility.localizedShortLabel(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.foreground, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({Color background, Color foreground}) _chipColors(
  BuildContext context,
  SpotListVisibility visibility,
  bool selected,
) {
  final scheme = Theme.of(context).colorScheme;
  if (!selected) {
    return (
      background: Colors.transparent,
      foreground: scheme.onSurface.withValues(alpha: 0.6),
    );
  }

  switch (visibility) {
    case SpotListVisibility.public:
      return (
        background: Colors.green.withValues(alpha: 0.1),
        foreground: Colors.green.shade700,
      );
    case SpotListVisibility.unlisted:
      return (
        background: Colors.orange.withValues(alpha: 0.1),
        foreground: Colors.orange.shade700,
      );
    case SpotListVisibility.private:
      return (
        background: Colors.blue.withValues(alpha: 0.1),
        foreground: Colors.blue.shade700,
      );
  }
}
