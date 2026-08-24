import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot.dart';
import '../services/auth_service.dart';
import '../services/spot_service.dart';
import '../utils/spot_duplicate_review.dart';

/// Result of [SpotDuplicateChangesDialog] when the moderator confirms.
class SpotDuplicateChangesResult {
  const SpotDuplicateChangesResult({
    this.dismissed = false,
    this.transferPhotos = false,
    this.transferYoutubeLinks = false,
    this.overwriteName = false,
    this.overwriteDescription = false,
    this.overwriteLocation = false,
    this.overwriteSpotAttributes = false,
  });

  final bool dismissed;
  final bool transferPhotos;
  final bool transferYoutubeLinks;
  final bool overwriteName;
  final bool overwriteDescription;
  final bool overwriteLocation;
  final bool overwriteSpotAttributes;
}

/// Confirm dialog to copy changed duplicate fields onto the original, or dismiss.
class SpotDuplicateChangesDialog extends StatefulWidget {
  const SpotDuplicateChangesDialog({
    super.key,
    required this.duplicateSpot,
    required this.originalName,
    required this.changedGroups,
  });

  final Spot duplicateSpot;
  final String originalName;
  final List<SpotDuplicateFieldGroup> changedGroups;

  @override
  State<SpotDuplicateChangesDialog> createState() =>
      _SpotDuplicateChangesDialogState();
}

class _SpotDuplicateChangesDialogState
    extends State<SpotDuplicateChangesDialog> {
  final Set<SpotDuplicateFieldGroup> _selected = {};

  bool _isSelected(SpotDuplicateFieldGroup group) => _selected.contains(group);

  void _toggle(SpotDuplicateFieldGroup group, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(group);
      } else {
        _selected.remove(group);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = widget.changedGroups;

    return AlertDialog(
      title: Text(l10n.spotDuplicateChangesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.spotDuplicateChangesBody(widget.originalName)),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...groups.map((group) {
                return CheckboxListTile(
                  title: Text(group.label(l10n)),
                  subtitle: Text(
                    formatSpotDuplicateFieldGroupValue(
                      spot: widget.duplicateSpot,
                      group: group,
                      l10n: l10n,
                    ),
                  ),
                  value: _isSelected(group),
                  onChanged: (value) => _toggle(group, value),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const SpotDuplicateChangesResult(dismissed: true)),
          child: Text(l10n.spotDuplicateChangesDismiss),
        ),
        FilledButton(
          onPressed: groups.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  SpotDuplicateChangesResult(
                    transferPhotos: _isSelected(SpotDuplicateFieldGroup.photos),
                    transferYoutubeLinks: _isSelected(
                      SpotDuplicateFieldGroup.youtube,
                    ),
                    overwriteName: _isSelected(SpotDuplicateFieldGroup.name),
                    overwriteDescription: _isSelected(
                      SpotDuplicateFieldGroup.description,
                    ),
                    overwriteLocation: _isSelected(
                      SpotDuplicateFieldGroup.location,
                    ),
                    overwriteSpotAttributes: _isSelected(
                      SpotDuplicateFieldGroup.attributes,
                    ),
                  ),
                ),
          child: Text(l10n.spotDuplicateChangesApply),
        ),
      ],
    );
  }
}

/// Staff callout when a duplicate has unreviewed field changes.
class SpotDuplicateChangesBanner extends StatelessWidget {
  const SpotDuplicateChangesBanner({
    super.key,
    required this.changedGroups,
    required this.onReview,
    required this.onDismiss,
  });

  final List<SpotDuplicateFieldGroup> changedGroups;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final labels = changedGroups.map((group) => group.label(l10n)).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 22,
                color: colors.onTertiaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.spotDuplicateChangesBannerTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.spotDuplicateChangesBannerBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onTertiaryContainer.withValues(
                          alpha: 0.9,
                        ),
                        height: 1.45,
                      ),
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        labels,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onReview,
                child: Text(l10n.spotDuplicateChangesReview),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(l10n.spotDuplicateChangesDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the take-over dialog and persists apply/dismiss. Returns false if cancelled.
Future<bool> reviewSpotDuplicateChanges({
  required BuildContext context,
  required Spot duplicateSpot,
  bool dismissWithoutDialog = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final spots = context.read<SpotService>();
  final auth = context.read<AuthService>();
  final userId = auth.currentUser?.uid;
  final userName =
      auth.userProfile?.displayName ??
      auth.currentUser?.displayName ??
      auth.currentUser?.email;

  if (dismissWithoutDialog) {
    final ok = await spots.dismissDuplicatePendingChanges(
      duplicateSpotId: duplicateSpot.id ?? '',
      userId: userId,
      userName: userName,
    );
    if (!context.mounted) return ok;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.spotDuplicateChangesDismissSuccess
              : (spots.error ?? l10n.spotDuplicateChangesFailed),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    return ok;
  }

  final originalId = duplicateSpot.duplicateOf?.trim();
  var originalName = l10n.spotDetailOriginalSpotFallback;
  if (originalId != null && originalId.isNotEmpty) {
    final original = await spots.getSpotById(originalId);
    final name = original?.name.trim();
    if (name != null && name.isNotEmpty) {
      originalName = name;
    }
  }
  if (!context.mounted) return false;

  final groups = parseSpotDuplicateChangedFieldGroups(
    duplicateSpot.duplicateChangedFields,
  );
  final result = await showDialog<SpotDuplicateChangesResult>(
    context: context,
    builder: (context) => SpotDuplicateChangesDialog(
      duplicateSpot: duplicateSpot,
      originalName: originalName,
      changedGroups: groups,
    ),
  );
  if (result == null || !context.mounted) return false;

  final bool ok;
  if (result.dismissed) {
    ok = await spots.dismissDuplicatePendingChanges(
      duplicateSpotId: duplicateSpot.id ?? '',
      userId: userId,
      userName: userName,
    );
  } else {
    ok = await spots.applyDuplicatePendingChanges(
      duplicateSpotId: duplicateSpot.id ?? '',
      transferPhotos: result.transferPhotos,
      transferYoutubeLinks: result.transferYoutubeLinks,
      overwriteName: result.overwriteName,
      overwriteDescription: result.overwriteDescription,
      overwriteLocation: result.overwriteLocation,
      overwriteSpotAttributes: result.overwriteSpotAttributes,
      userId: userId,
      userName: userName,
    );
  }
  if (!context.mounted) return ok;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? (result.dismissed
                  ? l10n.spotDuplicateChangesDismissSuccess
                  : l10n.spotDuplicateChangesApplySuccess)
            : (spots.error ?? l10n.spotDuplicateChangesFailed),
      ),
      backgroundColor: ok ? Colors.green : Colors.red,
    ),
  );
  return ok;
}
