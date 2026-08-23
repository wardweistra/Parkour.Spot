import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../services/auth_service.dart';
import '../utils/event_duplicate_review.dart';

/// Result of [EventDuplicateChangesDialog] when the moderator confirms.
class EventDuplicateChangesResult {
  const EventDuplicateChangesResult({
    this.dismissed = false,
    this.transferPhotos = false,
    this.transferLinkedSpots = false,
    this.overwriteTitle = false,
    this.overwriteDescription = false,
    this.overwriteLocation = false,
    this.overwriteSchedule = false,
    this.overwriteWebsite = false,
  });

  final bool dismissed;
  final bool transferPhotos;
  final bool transferLinkedSpots;
  final bool overwriteTitle;
  final bool overwriteDescription;
  final bool overwriteLocation;
  final bool overwriteSchedule;
  final bool overwriteWebsite;
}

/// Confirm dialog to copy changed duplicate fields onto the original, or dismiss.
class EventDuplicateChangesDialog extends StatefulWidget {
  const EventDuplicateChangesDialog({
    super.key,
    required this.duplicateEvent,
    required this.originalTitle,
    required this.changedGroups,
  });

  final ParkourEvent duplicateEvent;
  final String originalTitle;
  final List<EventDuplicateFieldGroup> changedGroups;

  @override
  State<EventDuplicateChangesDialog> createState() =>
      _EventDuplicateChangesDialogState();
}

class _EventDuplicateChangesDialogState
    extends State<EventDuplicateChangesDialog> {
  final Set<EventDuplicateFieldGroup> _selected = {};

  bool _isSelected(EventDuplicateFieldGroup group) => _selected.contains(group);

  void _toggle(EventDuplicateFieldGroup group, bool? value) {
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
      title: Text(l10n.eventDuplicateChangesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.eventDuplicateChangesBody(widget.originalTitle)),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...groups.map((group) {
                return CheckboxListTile(
                  title: Text(group.label(l10n)),
                  subtitle: Text(
                    formatEventDuplicateFieldGroupValue(
                      context: context,
                      event: widget.duplicateEvent,
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
          ).pop(const EventDuplicateChangesResult(dismissed: true)),
          child: Text(l10n.eventDuplicateChangesDismiss),
        ),
        FilledButton(
          onPressed: groups.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  EventDuplicateChangesResult(
                    transferPhotos: _isSelected(
                      EventDuplicateFieldGroup.photos,
                    ),
                    transferLinkedSpots: _isSelected(
                      EventDuplicateFieldGroup.linkedSpots,
                    ),
                    overwriteTitle: _isSelected(EventDuplicateFieldGroup.title),
                    overwriteDescription: _isSelected(
                      EventDuplicateFieldGroup.description,
                    ),
                    overwriteLocation: _isSelected(
                      EventDuplicateFieldGroup.location,
                    ),
                    overwriteSchedule: _isSelected(
                      EventDuplicateFieldGroup.schedule,
                    ),
                    overwriteWebsite: _isSelected(
                      EventDuplicateFieldGroup.website,
                    ),
                  ),
                ),
          child: Text(l10n.eventDuplicateChangesApply),
        ),
      ],
    );
  }
}

/// Staff callout when a duplicate has unreviewed field changes.
class EventDuplicateChangesBanner extends StatelessWidget {
  const EventDuplicateChangesBanner({
    super.key,
    required this.changedGroups,
    required this.onReview,
    required this.onDismiss,
  });

  final List<EventDuplicateFieldGroup> changedGroups;
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
                      l10n.eventDuplicateChangesBannerTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.eventDuplicateChangesBannerBody,
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
                child: Text(l10n.eventDuplicateChangesReview),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text(l10n.eventDuplicateChangesDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the take-over dialog and persists apply/dismiss. Returns false if cancelled.
Future<bool> reviewEventDuplicateChanges({
  required BuildContext context,
  required ParkourEvent duplicateEvent,
  bool dismissWithoutDialog = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final admin = context.read<AdminEventsService>();
  final auth = context.read<AuthService>();
  final userId = auth.currentUser?.uid;
  final userName =
      auth.userProfile?.displayName ??
      auth.currentUser?.displayName ??
      auth.currentUser?.email;

  if (dismissWithoutDialog) {
    final ok = await admin.dismissDuplicatePendingChanges(
      duplicateEventId: duplicateEvent.id ?? '',
      userId: userId,
      userName: userName,
    );
    if (!context.mounted) return ok;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.eventDuplicateChangesDismissSuccess
              : (admin.error ?? l10n.eventDuplicateChangesFailed),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    return ok;
  }

  final originalId = duplicateEvent.duplicateOf?.trim();
  var originalTitle = l10n.eventDetailOriginalEventFallback;
  if (originalId != null && originalId.isNotEmpty) {
    final original = await admin.getEventById(originalId);
    final title = original?.title.trim();
    if (title != null && title.isNotEmpty) {
      originalTitle = title;
    }
  }
  if (!context.mounted) return false;

  final groups = parseDuplicateChangedFieldGroups(
    duplicateEvent.duplicateChangedFields,
  );
  final result = await showDialog<EventDuplicateChangesResult>(
    context: context,
    builder: (context) => EventDuplicateChangesDialog(
      duplicateEvent: duplicateEvent,
      originalTitle: originalTitle,
      changedGroups: groups,
    ),
  );
  if (result == null || !context.mounted) return false;

  final bool ok;
  if (result.dismissed) {
    ok = await admin.dismissDuplicatePendingChanges(
      duplicateEventId: duplicateEvent.id ?? '',
      userId: userId,
      userName: userName,
    );
  } else {
    ok = await admin.applyDuplicatePendingChanges(
      duplicateEventId: duplicateEvent.id ?? '',
      transferPhotos: result.transferPhotos,
      transferLinkedSpots: result.transferLinkedSpots,
      overwriteTitle: result.overwriteTitle,
      overwriteDescription: result.overwriteDescription,
      overwriteLocation: result.overwriteLocation,
      overwriteSchedule: result.overwriteSchedule,
      overwriteWebsite: result.overwriteWebsite,
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
                  ? l10n.eventDuplicateChangesDismissSuccess
                  : l10n.eventDuplicateChangesApplySuccess)
            : (admin.error ?? l10n.eventDuplicateChangesFailed),
      ),
      backgroundColor: ok ? Colors.green : Colors.red,
    ),
  );
  return ok;
}
