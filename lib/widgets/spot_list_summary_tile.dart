import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../services/user_profile_service.dart';
import '../utils/spot_list_localization.dart';
import 'emoji_text.dart';

/// One list in a hub or public profile: name, optional description, visibility
/// and count. Not wrapped in a Card so parents can group with spacing, not nesting.
///
/// Set [showCreator] on Saved / Featured rows (and similar) where the viewer is
/// not already looking at the owner's own lists. Pass [creatorName] when the
/// parent already resolved it; otherwise the tile loads it from [createdBy].
class SpotListSummaryTile extends StatefulWidget {
  const SpotListSummaryTile({
    super.key,
    required this.list,
    required this.onTap,
    this.leading,
    this.showCreator = false,
    this.creatorName,
  });

  final SpotList list;
  final VoidCallback onTap;
  final Widget? leading;
  final bool showCreator;

  /// Optional pre-resolved display name. When null and [showCreator] is true,
  /// the tile fetches the creator profile.
  final String? creatorName;

  @override
  State<SpotListSummaryTile> createState() => _SpotListSummaryTileState();
}

class _SpotListSummaryTileState extends State<SpotListSummaryTile> {
  String? _resolvedCreatorName;
  bool _loadingCreator = false;

  SpotList get _list => widget.list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCreatorIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant SpotListSummaryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showCreator != widget.showCreator ||
        oldWidget.creatorName != widget.creatorName ||
        oldWidget.list.createdBy != widget.list.createdBy ||
        oldWidget.list.id != widget.list.id) {
      _resolvedCreatorName = null;
      _loadingCreator = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCreatorIfNeeded();
      });
    }
  }

  Future<void> _loadCreatorIfNeeded() async {
    if (!widget.showCreator) return;

    final provided = widget.creatorName?.trim();
    if (provided != null && provided.isNotEmpty) {
      setState(() {
        _resolvedCreatorName = provided;
        _loadingCreator = false;
      });
      return;
    }

    final uid = _list.createdBy.trim();
    if (uid.isEmpty) return;

    setState(() => _loadingCreator = true);
    try {
      final profile = await context.read<UserProfileService>().getUserProfile(
        uid,
      );
      if (!mounted) return;
      final displayName = profile?.displayName?.trim();
      final username = profile?.username?.trim();
      setState(() {
        _resolvedCreatorName = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (username != null && username.isNotEmpty)
            ? username
            : null;
        _loadingCreator = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCreator = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = _list.description?.trim();
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.6),
    );
    final effectiveCreator = widget.creatorName?.trim().isNotEmpty == true
        ? widget.creatorName!.trim()
        : _resolvedCreatorName;
    final hasCreator =
        !_loadingCreator &&
        effectiveCreator != null &&
        effectiveCreator.isNotEmpty;
    final meta = hasCreator
        ? _list.visibility.localizedVisibilityCountAndCreator(
            l10n,
            _list.spotCount,
            effectiveCreator,
          )
        : _list.visibility.localizedVisibilityAndCount(l10n, _list.spotCount);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: widget.leading,
      title: EmojiText(
        _list.name,
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
            child: Row(
              children: [
                if (_list.featured) ...[
                  Icon(Icons.star, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.spotListFeaturedBadgeShort,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(' · ', style: mutedStyle),
                ],
                Flexible(
                  child: Text(
                    meta,
                    style: mutedStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: widget.onTap,
    );
  }
}
