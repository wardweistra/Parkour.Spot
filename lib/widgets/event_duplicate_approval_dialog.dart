import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/event_report.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../services/auth_service.dart';
import '../services/event_report_service.dart';
import 'event_duplicate_picker.dart';
import 'event_duplicate_transfer_dialog.dart';
import 'event_selection_dialog.dart';

class EventDuplicateApprovalDialog extends StatefulWidget {
  const EventDuplicateApprovalDialog({super.key, required this.report});

  final EventReport report;

  @override
  State<EventDuplicateApprovalDialog> createState() =>
      _EventDuplicateApprovalDialogState();
}

class _EventDuplicateApprovalDialogState
    extends State<EventDuplicateApprovalDialog> {
  ParkourEvent? _suggestedOriginal;
  ParkourEvent? _resolvedNativeOriginal;
  ParkourEvent? _targetEvent;
  bool _loading = true;
  bool _approving = false;
  String? _error;
  bool _needsNativePick = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestedOriginal();
  }

  Future<void> _loadSuggestedOriginal() async {
    final duplicateId = widget.report.duplicateOfEventId?.trim();
    if (duplicateId == null || duplicateId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing suggested original event.';
      });
      return;
    }

    try {
      final admin = context.read<AdminEventsService>();
      final targetId = widget.report.targetEventId?.trim();
      final results = await Future.wait([
        admin.getEventById(duplicateId),
        if (targetId != null && targetId.isNotEmpty)
          admin.getEventById(targetId)
        else
          Future<ParkourEvent?>.value(null),
      ]);
      if (!mounted) return;

      final event = results[0];
      final target = results[1];

      if (event == null) {
        setState(() {
          _targetEvent = target;
          _loading = false;
          _error = 'Suggested original event was not found.';
          _needsNativePick = true;
        });
        return;
      }

      final needsPick = !isValidNativeDuplicateOriginal(event);
      setState(() {
        _suggestedOriginal = event;
        _resolvedNativeOriginal = needsPick ? null : event;
        _targetEvent = target;
        _needsNativePick = needsPick;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load suggested original event.';
        _needsNativePick = true;
      });
    }
  }

  Future<void> _pickNativeOriginal() async {
    final targetId = widget.report.targetEventId?.trim();
    if (targetId == null) return;

    final pickedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => EventSelectionDialog(
        currentEventId: targetId,
        referenceStartAt: widget.report.startAt,
        referenceEndAt: widget.report.endAt,
      ),
    );
    if (pickedId == null || !mounted) return;

    final event = await context.read<AdminEventsService>().getEventById(
      pickedId,
    );
    if (!mounted || event == null) return;

    if (!isValidNativeDuplicateOriginal(event)) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.eventDetailMarkDuplicateTargetNotNative;
      });
      return;
    }

    setState(() {
      _resolvedNativeOriginal = event;
      _error = null;
    });
  }

  Future<void> _approve() async {
    final resolved = _resolvedNativeOriginal;
    final resolvedId = resolved?.id?.trim();
    if (resolvedId == null || resolvedId.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        )!.eventDuplicateApprovalPickNativeTitle;
      });
      return;
    }

    final targetEvent = _targetEvent;
    EventDuplicateTransferResult transferResult =
        const EventDuplicateTransferResult();

    if (targetEvent != null) {
      final dialogResult = await showDialog<EventDuplicateTransferResult>(
        context: context,
        builder: (dialogContext) => EventDuplicateTransferDialog(
          duplicateEvent: targetEvent,
          originalTitle: resolved!.title,
          showReportSelector: false,
        ),
      );
      if (!mounted) return;
      if (dialogResult == null) return;
      transferResult = dialogResult;
    }

    setState(() {
      _approving = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final userId = user?.uid;
    if (userId == null) {
      if (mounted) setState(() => _approving = false);
      return;
    }

    final targetEventId = await context
        .read<EventReportService>()
        .approveDuplicateReport(
          reportId: widget.report.id,
          approverUserId: userId,
          nativeOriginalEventId: resolvedId,
          adminEventsService: context.read<AdminEventsService>(),
          approverName:
              auth.userProfile?.displayName ??
              user?.displayName ??
              user?.email,
          moderatorNotes: transferResult.notes,
          transferPhotos: transferResult.transferPhotos,
          transferLinkedSpots: transferResult.transferLinkedSpots,
          overwriteTitle: transferResult.overwriteTitle,
          overwriteDescription: transferResult.overwriteDescription,
          overwriteLocation: transferResult.overwriteLocation,
          overwriteSchedule: transferResult.overwriteSchedule,
          overwriteWebsite: transferResult.overwriteWebsite,
        );

    if (!mounted) return;

    if (targetEventId == null) {
      final adminError = context.read<AdminEventsService>().error;
      setState(() {
        _approving = false;
        _error =
            adminError ??
            AppLocalizations.of(
              context,
            )!.eventDetailMarkDuplicateNotFoundOrInvalid;
      });
      return;
    }

    Navigator.of(context).pop(targetEventId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final suggested = _suggestedOriginal;
    final resolved = _resolvedNativeOriginal;

    return AlertDialog(
      title: Text(l10n.eventReportQueueApproveDuplicate),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.eventDetailMarkDuplicateConfirmBody(
                        resolved?.title ??
                            suggested?.title ??
                            widget.report.duplicateOfEventTitle ??
                            '',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (suggested != null && !suggested.isNativeEvent) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.eventDuplicateApprovalExternalOriginalHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                    if (_needsNativePick) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.eventDuplicateApprovalPickNativeTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (resolved == null)
                        OutlinedButton.icon(
                          onPressed: _approving ? null : _pickNativeOriginal,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(l10n.eventDetailMarkDuplicatePickNativeTitle),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(resolved.title),
                          subtitle: Text(
                            l10n.eventDetailMarkDuplicateUseButton,
                          ),
                          trailing: TextButton(
                            onPressed: _approving ? null : _pickNativeOriginal,
                            child: Text(l10n.eventDetailMarkDuplicatePickNativeTitle),
                          ),
                        ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _approving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancel),
        ),
        FilledButton(
          onPressed: _loading || _approving || resolved == null ? null : _approve,
          child: _approving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.eventReportQueueApproveDuplicate),
        ),
      ],
    );
  }
}
