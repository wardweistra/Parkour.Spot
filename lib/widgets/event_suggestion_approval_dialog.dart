import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/event_report.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../services/auth_service.dart';
import '../services/event_report_service.dart';
import 'event_suggested_edits_summary.dart';

class EventSuggestionApprovalDialog extends StatefulWidget {
  const EventSuggestionApprovalDialog({super.key, required this.report});

  final EventReport report;

  @override
  State<EventSuggestionApprovalDialog> createState() =>
      _EventSuggestionApprovalDialogState();
}

class _EventSuggestionApprovalDialogState
    extends State<EventSuggestionApprovalDialog> {
  bool _isLoading = true;
  bool _isApproving = false;
  String? _error;

  ParkourEvent? _currentEvent;
  ParkourEvent? _originalEvent;
  String? _targetEventId;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final targetEventId = widget.report.targetEventId?.trim();
    if (targetEventId == null || targetEventId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final adminEventsService = Provider.of<AdminEventsService>(
        context,
        listen: false,
      );
      final currentEvent = await adminEventsService.getEventById(targetEventId);
      if (currentEvent == null || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      ParkourEvent? originalEvent;
      final duplicateOf = currentEvent.duplicateOf?.trim();
      if (duplicateOf != null && duplicateOf.isNotEmpty) {
        originalEvent = await adminEventsService.getEventById(duplicateOf);
      }

      if (!mounted) return;
      setState(() {
        _currentEvent = currentEvent;
        _originalEvent = originalEvent;
        _targetEventId = originalEvent?.id ?? currentEvent.id;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading events for suggestion approval: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ParkourEvent? get _targetEvent {
    if (_targetEventId != null &&
        _originalEvent?.id != null &&
        _targetEventId == _originalEvent!.id) {
      return _originalEvent;
    }
    return _currentEvent;
  }

  bool get _isTargetEventFromSource {
    if (_targetEventId != null &&
        _targetEventId != widget.report.targetEventId &&
        _originalEvent != null) {
      return !_originalEvent!.isNativeEvent;
    }
    return _currentEvent != null && !_currentEvent!.isNativeEvent;
  }

  bool get _isTargetEventDuplicate {
    if (_targetEventId == widget.report.targetEventId) {
      final duplicateOf = _currentEvent?.duplicateOf?.trim();
      return duplicateOf != null && duplicateOf.isNotEmpty;
    }
    return false;
  }

  bool _canApprove() {
    if (_targetEvent == null) return false;
    if (_isTargetEventFromSource) return false;
    if (_isTargetEventDuplicate) return false;
    return true;
  }

  Future<void> _approve() async {
    if (!_canApprove() || _isApproving) return;

    final targetEventId = _targetEventId?.trim();
    if (targetEventId == null || targetEventId.isEmpty) return;

    setState(() {
      _isApproving = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final reportService = Provider.of<EventReportService>(
        context,
        listen: false,
      );
      final user = authService.currentUser;
      final userId = user?.uid;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _error = AppLocalizations.of(
              context,
            )!.eventSuggestionApprovalFailed;
            _isApproving = false;
          });
        }
        return;
      }

      final notes = _notesController.text.trim();
      final approvedEventId = await reportService.approveReport(
        reportId: widget.report.id,
        approverUserId: userId,
        approverName:
            authService.userProfile?.displayName ??
            user?.displayName ??
            user?.email,
        moderatorNotes: notes.isEmpty ? null : notes,
        targetEventIdOverride: targetEventId,
      );

      if (!mounted) return;

      if (approvedEventId == null) {
        setState(() {
          _error = AppLocalizations.of(context)!.eventSuggestionApprovalFailed;
          _isApproving = false;
        });
        return;
      }

      Navigator.of(context).pop(approvedEventId);
    } catch (e) {
      debugPrint('Error approving event suggestion: $e');
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!.eventSuggestionApprovalFailed;
          _isApproving = false;
        });
      }
    }
  }

  LatLng? _currentLocationForMap(ParkourEvent event) {
    if (event.latitude != null && event.longitude != null) {
      return LatLng(event.latitude!, event.longitude!);
    }
    return null;
  }

  Widget _buildWarningBanner({
    required ThemeData theme,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final report = widget.report;
    final targetEvent = _targetEvent;

    if (_isLoading || targetEvent == null) {
      return AlertDialog(
        title: Text(l10n.eventSuggestionApprovalTitle),
        content: const SizedBox(
          width: 400,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final sourceName = targetEvent.eventSourceName?.trim().isNotEmpty == true
        ? targetEvent.eventSourceName!.trim()
        : 'external source';

    return AlertDialog(
      title: Text(l10n.eventSuggestionApprovalTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                report.targetEventTitle?.trim().isNotEmpty == true
                    ? report.targetEventTitle!.trim()
                    : report.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_isTargetEventFromSource) ...[
                _buildWarningBanner(
                  theme: theme,
                  title: l10n.eventSuggestionCannotApproveExternalTitle,
                  body: l10n.eventSuggestionCannotApproveExternalBody(
                    sourceName,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isTargetEventDuplicate) ...[
                _buildWarningBanner(
                  theme: theme,
                  title: l10n.eventSuggestionCannotApproveDuplicateTitle,
                  body: l10n.eventSuggestionCannotApproveDuplicateBody,
                ),
                const SizedBox(height: 16),
              ],
              if (_originalEvent != null) ...[
                Text(
                  l10n.eventSuggestionTargetEventLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _targetEventId,
                  onChanged: (String? value) {
                    final isCurrentDisabled =
                        _isApproving ||
                        (_currentEvent?.duplicateOf?.trim().isNotEmpty ??
                            false) ||
                        !_currentEvent!.isNativeEvent;
                    final isOriginalDisabled =
                        _isApproving || !_originalEvent!.isNativeEvent;

                    if (value == widget.report.targetEventId &&
                        isCurrentDisabled) {
                      return;
                    }
                    if (value == _originalEvent!.id && isOriginalDisabled) {
                      return;
                    }

                    setState(() => _targetEventId = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          l10n.eventSuggestionCurrentEventLabel(
                            report.targetEventTitle?.trim().isNotEmpty == true
                                ? report.targetEventTitle!.trim()
                                : report.title,
                          ),
                        ),
                        subtitle: Text(
                          _currentEvent?.duplicateOf?.trim().isNotEmpty == true
                              ? l10n.eventSuggestionReportedEventDuplicateSubtitle(
                                  _originalEvent?.title ?? '',
                                )
                              : !_currentEvent!.isNativeEvent
                              ? l10n.eventSuggestionReportedEventExternalSubtitle(
                                  _currentEvent!.eventSourceName
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? _currentEvent!.eventSourceName!.trim()
                                      : sourceName,
                                )
                              : l10n.eventSuggestionReportedEventSubtitle,
                        ),
                        value: widget.report.targetEventId!,
                        enabled:
                            !_isApproving &&
                            !(_currentEvent?.duplicateOf?.trim().isNotEmpty ??
                                false) &&
                            _currentEvent!.isNativeEvent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: Text(
                          l10n.eventSuggestionOriginalEventLabel(
                            _originalEvent!.title,
                          ),
                        ),
                        subtitle: Text(
                          !_originalEvent!.isNativeEvent
                              ? l10n.eventSuggestionOriginalEventExternalSubtitle(
                                  _originalEvent!.eventSourceName
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? _originalEvent!.eventSourceName!.trim()
                                      : sourceName,
                                )
                              : l10n.eventSuggestionOriginalEventRecommendedSubtitle,
                        ),
                        value: _originalEvent!.id!,
                        enabled: !_isApproving && _originalEvent!.isNativeEvent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (report.hasSuggestedEdits) ...[
                EventSuggestedEditsSummary(
                  report: report,
                  sectionTitle: l10n.eventDetailQuickActionSuggestEdit,
                  currentLocation: _currentLocationForMap(targetEvent),
                ),
                const SizedBox(height: 12),
              ],
              if (report.suggestedPhotoUrls.isNotEmpty) ...[
                Text(
                  l10n.eventDetailQuickActionSuggestPhoto,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: report.suggestedPhotoUrls.map((photoUrl) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                l10n.eventSuggestionModeratorNotesLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.eventSuggestionModeratorNotesHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
                enabled: !_isApproving,
              ),
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
          onPressed: _isApproving
              ? null
              : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isApproving || !_canApprove()) ? null : _approve,
          child: _isApproving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.eventSuggestionApproveButton),
        ),
      ],
    );
  }
}
