import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../utils/event_duplicate_merge.dart';
import 'moderator_action_fields.dart';

/// Result of [EventDuplicateTransferDialog] when the moderator confirms.
class EventDuplicateTransferResult {
  const EventDuplicateTransferResult({
    this.transferPhotos = false,
    this.transferLinkedSpots = false,
    this.overwriteTitle = false,
    this.overwriteDescription = false,
    this.overwriteLocation = false,
    this.overwriteSchedule = false,
    this.overwriteWebsite = false,
    this.reportId,
    this.notes,
  });

  final bool transferPhotos;
  final bool transferLinkedSpots;
  final bool overwriteTitle;
  final bool overwriteDescription;
  final bool overwriteLocation;
  final bool overwriteSchedule;
  final bool overwriteWebsite;
  final String? reportId;
  final String? notes;
}

/// Confirm dialog with optional transfer/overwrite checkboxes when marking an
/// event as a duplicate of [originalTitle].
class EventDuplicateTransferDialog extends StatefulWidget {
  const EventDuplicateTransferDialog({
    super.key,
    required this.duplicateEvent,
    required this.originalTitle,
    this.showReportSelector = true,
  });

  /// The event being marked as a duplicate (source of transferable data).
  final ParkourEvent duplicateEvent;

  /// Title of the chosen native original (for confirm copy).
  final String originalTitle;

  /// When false, hides the linked-report selector (e.g. approving a report).
  final bool showReportSelector;

  @override
  State<EventDuplicateTransferDialog> createState() =>
      _EventDuplicateTransferDialogState();
}

class _EventDuplicateTransferDialogState
    extends State<EventDuplicateTransferDialog> {
  bool _transferPhotos = false;
  bool _transferLinkedSpots = false;
  bool _overwriteTitle = false;
  bool _overwriteDescription = false;
  bool _overwriteLocation = false;
  bool _overwriteSchedule = false;
  bool _overwriteWebsite = false;
  final TextEditingController _notesController = TextEditingController();
  String? _selectedReportId;

  ParkourEvent get _event => widget.duplicateEvent;

  bool get _hasPhotos => eventHasTransferablePhotos(_event);
  bool get _hasLinkedSpots => eventHasTransferableLinkedSpots(_event);
  bool get _hasTitle => eventHasOverwriteTitle(_event);
  bool get _hasDescription => eventHasOverwriteDescription(_event);
  bool get _hasLocation => eventHasOverwriteLocation(_event);
  bool get _hasSchedule => eventHasOverwriteSchedule(_event);
  bool get _hasWebsite => eventHasOverwriteWebsite(_event);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasTransferOptions = _hasPhotos || _hasLinkedSpots;
    final hasOverwriteOptions = _hasTitle ||
        _hasDescription ||
        _hasLocation ||
        _hasSchedule ||
        _hasWebsite;
    final eventId = _event.id;

    return AlertDialog(
      title: Text(l10n.eventDetailMarkDuplicateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.eventDetailMarkDuplicateBody(widget.originalTitle),
            ),
            if (hasTransferOptions || hasOverwriteOptions) ...[
              const SizedBox(height: 16),
              if (hasTransferOptions) ...[
                Text(l10n.eventDetailMarkDuplicateAddToOriginal),
                const SizedBox(height: 8),
                if (_hasPhotos)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicatePhotos),
                    value: _transferPhotos,
                    onChanged: (value) {
                      setState(() => _transferPhotos = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasLinkedSpots)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateLinkedSpots),
                    value: _transferLinkedSpots,
                    onChanged: (value) {
                      setState(() => _transferLinkedSpots = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
              if (hasOverwriteOptions) ...[
                if (hasTransferOptions) const SizedBox(height: 16),
                Text(l10n.eventDetailMarkDuplicateOverwrite),
                const SizedBox(height: 8),
                if (_hasTitle)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateEventTitle),
                    value: _overwriteTitle,
                    onChanged: (value) {
                      setState(() => _overwriteTitle = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasDescription)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateDescription),
                    value: _overwriteDescription,
                    onChanged: (value) {
                      setState(() => _overwriteDescription = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasLocation)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateLocation),
                    value: _overwriteLocation,
                    onChanged: (value) {
                      setState(() => _overwriteLocation = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasSchedule)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateSchedule),
                    value: _overwriteSchedule,
                    onChanged: (value) {
                      setState(() => _overwriteSchedule = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasWebsite)
                  CheckboxListTile(
                    title: Text(l10n.eventDetailMarkDuplicateWebsite),
                    value: _overwriteWebsite,
                    onChanged: (value) {
                      setState(() => _overwriteWebsite = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ],
            if (eventId != null) ...[
              const SizedBox(height: 16),
              ModeratorActionFields(
                eventId: eventId,
                notesController: _notesController,
                onReportSelected: (reportId) {
                  setState(() => _selectedReportId = reportId);
                },
                showReportSelector: widget.showReportSelector,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            EventDuplicateTransferResult(
              transferPhotos: _transferPhotos,
              transferLinkedSpots: _transferLinkedSpots,
              overwriteTitle: _overwriteTitle,
              overwriteDescription: _overwriteDescription,
              overwriteLocation: _overwriteLocation,
              overwriteSchedule: _overwriteSchedule,
              overwriteWebsite: _overwriteWebsite,
              reportId: _selectedReportId,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          ),
          child: Text(l10n.spotDetailConfirm),
        ),
      ],
    );
  }
}
