import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'event_duplicate_picker.dart';

/// Admin dialog: choose a **native** event (not a duplicate) as the canonical original.
class EventSelectionDialog extends StatefulWidget {
  const EventSelectionDialog({
    super.key,
    required this.currentEventId,
    required this.referenceStartAt,
    this.referenceEndAt,
  });

  final String currentEventId;
  final DateTime referenceStartAt;
  final DateTime? referenceEndAt;

  @override
  State<EventSelectionDialog> createState() => _EventSelectionDialogState();
}

class _EventSelectionDialogState extends State<EventSelectionDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.eventDetailMarkDuplicatePickNativeTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: EventDuplicatePicker(
            currentEventId: widget.currentEventId,
            referenceStartAt: widget.referenceStartAt,
            referenceEndAt: widget.referenceEndAt,
            nativeOnlyOriginals: true,
            onEventSelected: (event) {
              final id = event.id;
              if (id != null) {
                Navigator.of(context).pop<String>(id);
              }
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<String>(),
          child: Text(l10n.profileCancel),
        ),
      ],
    );
  }
}
