import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_report.dart';
import '../../services/auth_service.dart';
import '../../services/event_report_service.dart';
import '../../utils/event_schedule_utils.dart';
import '../../widgets/location_review_map.dart';
import '../../widgets/event_duplicate_approval_dialog.dart';
import '../../widgets/event_suggested_edits_summary.dart';
import '../../widgets/event_suggestion_approval_dialog.dart';
import '../../widgets/image_processing_banner.dart';
import '../../widgets/page_scaffold.dart';
import '../../utils/ui_yield.dart';

class EventReportQueueScreen extends StatefulWidget {
  const EventReportQueueScreen({super.key});

  @override
  State<EventReportQueueScreen> createState() => _EventReportQueueScreenState();
}

class _EventReportQueueScreenState extends State<EventReportQueueScreen> {
  static const String _allFilter = 'All';
  late final List<String> _filters = <String>[
    _allFilter,
    ...EventReportService.statuses,
  ];
  String _selectedFilter = EventReportService.statuses.first;
  final Set<String> _busyReportIds = <String>{};
  final Map<String, String> _busyProgressLabels = <String, String>{};

  void _updateBusyProgress(
    String reportId, {
    required String message,
    String? progressLabel,
  }) {
    if (!mounted) return;
    setState(() {
      _busyReportIds.add(reportId);
      _busyProgressLabels[reportId] = progressLabel == null
          ? message
          : '$message $progressLabel';
    });
  }

  void _clearBusy(String reportId) {
    if (!mounted) return;
    setState(() {
      _busyReportIds.remove(reportId);
      _busyProgressLabels.remove(reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventReportService>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();
    return PageScaffold(
      title: 'Event report queue',
      scrollable: false,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/moderator');
        }
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review user-submitted event proposals and suggestions.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<EventReport>>(
            initialData: service.latestEventReports,
            stream: service.watchEventReports(),
            builder: (context, snapshot) {
              final allReports = snapshot.data ?? const <EventReport>[];
              final statusCounts = <String, int>{
                _allFilter: allReports.length,
                for (final status in EventReportService.statuses)
                  status: allReports.where((r) => r.status == status).length,
              };

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filters.map((filter) {
                  final count = statusCounts[filter] ?? 0;
                  final isSelected = filter == _selectedFilter;
                  return ChoiceChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(filter),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.onSecondaryContainer
                                  : theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<EventReport>>(
              initialData: service.latestEventReports,
              stream: service.watchEventReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildMessage(
                    icon: Icons.error_outline,
                    title: 'Failed to load event reports',
                    message: 'Please try again shortly.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports =
                    (snapshot.data ?? const <EventReport>[])
                        .where(
                          (report) =>
                              _selectedFilter == _allFilter ||
                              report.status == _selectedFilter,
                        )
                        .toList()
                      ..sort((a, b) {
                        final at =
                            a.createdAt ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bt =
                            b.createdAt ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bt.compareTo(at);
                      });
                if (reports.isEmpty) {
                  return _buildMessage(
                    icon: Icons.inbox_outlined,
                    title: 'Nothing to review',
                    message: 'Incoming event reports will appear here.',
                  );
                }

                return ListView.separated(
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _EventReportCard(
                      report: report,
                      dateFormat: dateFormat,
                      isBusy: _busyReportIds.contains(report.id),
                      busyProgressLabel: _busyProgressLabels[report.id],
                      onSetStatus: (status) => _setStatus(report, status),
                      onApprove: () => _approve(report),
                      onReject: () => _reject(report),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(EventReport report, String status) async {
    if (_busyReportIds.contains(report.id)) return;
    setState(() => _busyReportIds.add(report.id));
    final auth = context.read<AuthService>();
    final ok = await context.read<EventReportService>().updateReportStatus(
      reportId: report.id,
      status: status,
      reviewedBy: auth.currentUser?.uid,
      reviewedByName:
          auth.userProfile?.displayName ??
          auth.currentUser?.displayName ??
          auth.currentUser?.email,
    );
    if (!mounted) return;
    setState(() => _busyReportIds.remove(report.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Report marked as $status.' : 'Could not set status to $status.',
        ),
      ),
    );
  }

  Future<void> _approve(EventReport report) async {
    if (_busyReportIds.contains(report.id)) return;

    if (report.isDuplicateSuggestion) {
      await _approveDuplicate(report);
      return;
    }

    if (report.isSuggestionForExistingEvent) {
      await _approveSuggestion(report);
      return;
    }

    if (!mounted) return;
    _updateBusyProgress(report.id, message: 'Starting approval...');
    await yieldToUi();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final userId = user?.uid;
    if (userId == null) {
      _clearBusy(report.id);
      return;
    }

    final eventId = await context.read<EventReportService>().approveReport(
      reportId: report.id,
      approverUserId: userId,
      approverName:
          auth.userProfile?.displayName ?? user?.displayName ?? user?.email,
      onPhotoProgress: report.suggestedPhotoUrls.isEmpty
          ? null
          : (current, total, {phase = 'Processing'}) {
              _updateBusyProgress(
                report.id,
                message: '$phase photo',
                progressLabel: '($current / $total)',
              );
            },
    );

    if (!mounted) return;
    _clearBusy(report.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          eventId == null
              ? 'Could not approve this event report.'
              : 'Approved and published as event $eventId.',
        ),
      ),
    );
  }

  Future<void> _approveSuggestion(EventReport report) async {
    if (_busyReportIds.contains(report.id)) return;
    setState(() => _busyReportIds.add(report.id));

    final approvedEventId = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => EventSuggestionApprovalDialog(report: report),
    );

    if (!mounted) return;
    setState(() => _busyReportIds.remove(report.id));

    if (approvedEventId == null) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.eventSuggestionApprovalSuccess(approvedEventId)),
      ),
    );
  }

  Future<void> _approveDuplicate(EventReport report) async {
    if (_busyReportIds.contains(report.id)) return;
    setState(() => _busyReportIds.add(report.id));

    final approvedEventId = await showDialog<String?>(
      context: context,
      builder: (dialogContext) =>
          EventDuplicateApprovalDialog(report: report),
    );

    if (!mounted) return;
    setState(() => _busyReportIds.remove(report.id));

    if (approvedEventId == null) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.eventSuggestionApprovalSuccess(approvedEventId)),
      ),
    );
  }

  Future<void> _reject(EventReport report) async {
    if (_busyReportIds.contains(report.id)) return;
    final notesController = TextEditingController();
    final rejected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject event report?'),
        content: TextField(
          controller: notesController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (rejected != true) return;
    if (!mounted) return;

    setState(() => _busyReportIds.add(report.id));
    final auth = context.read<AuthService>();
    final eventReportService = context.read<EventReportService>();
    final user = auth.currentUser;
    final reviewerUserId = user?.uid;
    if (reviewerUserId == null) {
      _clearBusy(report.id);
      return;
    }

    await yieldToUi();
    final ok = await eventReportService.rejectReport(
      reportId: report.id,
      reviewerUserId: reviewerUserId,
      reviewerName:
          auth.userProfile?.displayName ?? user?.displayName ?? user?.email,
      moderatorNotes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      onPhotoProgress: report.suggestedPhotoUrls.isEmpty
          ? null
          : (current, total) {
              _updateBusyProgress(
                report.id,
                message: 'Rejecting photo',
                progressLabel: '($current / $total)',
              );
            },
    );

    if (!mounted) return;
    _clearBusy(report.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Report rejected.' : 'Could not reject this report.',
        ),
      ),
    );
  }
}

class _EventReportCard extends StatelessWidget {
  const _EventReportCard({
    required this.report,
    required this.dateFormat,
    required this.isBusy,
    this.busyProgressLabel,
    required this.onSetStatus,
    required this.onApprove,
    required this.onReject,
  });

  final EventReport report;
  final DateFormat dateFormat;
  final bool isBusy;
  final String? busyProgressLabel;
  final ValueChanged<String> onSetStatus;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color _statusColor(ThemeData theme) {
    switch (report.status) {
      case 'Approved':
        return theme.colorScheme.primary;
      case 'Rejected':
        return theme.colorScheme.error;
      case 'Reviewing':
        return theme.colorScheme.tertiary;
      case 'New':
      default:
        return theme.colorScheme.secondary;
    }
  }

  String _scheduleSummary(BuildContext context) {
    return EventScheduleUtils.formatSummaryLine(
      context,
      startAt: report.startAt,
      endAt: report.endAt,
      isDateOnly: report.isDateOnly,
      timeZone: report.timeZone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = _statusColor(theme);
    final canReview = report.status == 'New' || report.status == 'Reviewing';
    final isSuggestion = report.isSuggestionForExistingEvent;
    final isDuplicateSuggestion = report.isDuplicateSuggestion;
    final hasSuggestedEdits = report.hasSuggestedEdits;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSuggestion && report.targetEventId?.trim().isNotEmpty == true)
              InkWell(
                onTap: () =>
                    context.push('/event/${report.targetEventId!.trim()}'),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          report.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(report.title, style: theme.textTheme.titleMedium),
            if (isSuggestion) ...[
              const SizedBox(height: 4),
              Text(
                'Suggestion for existing event',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _metaChip(
                  context,
                  icon: Icons.calendar_month_outlined,
                  label: _scheduleSummary(context),
                ),
                _metaChip(
                  context,
                  icon: Icons.flag_outlined,
                  label: report.status,
                ),
                if (report.reporterName?.isNotEmpty ?? false)
                  _metaChip(
                    context,
                    icon: Icons.person_outline,
                    label: report.reporterName!,
                  ),
                if (report.createdAt != null)
                  _metaChip(
                    context,
                    icon: Icons.schedule_outlined,
                    label: dateFormat.format(report.createdAt!.toLocal()),
                  ),
                if (report.linkedSpotName?.isNotEmpty ?? false)
                  _metaChip(
                    context,
                    icon: Icons.location_on_outlined,
                    label: 'Spot: ${report.linkedSpotName!}',
                  ),
                if (report.linkedSpotListName?.isNotEmpty ?? false)
                  _metaChip(
                    context,
                    icon: Icons.list_alt_outlined,
                    label: 'List: ${report.linkedSpotListName!}',
                  ),
                if (report.locationSummary != null)
                  _metaChip(
                    context,
                    icon: Icons.map_outlined,
                    label: report.locationSummary!,
                  ),
                if (isSuggestion)
                  _metaChip(
                    context,
                    icon: isDuplicateSuggestion
                        ? Icons.copy_all_outlined
                        : hasSuggestedEdits
                        ? Icons.edit_note_outlined
                        : Icons.add_photo_alternate_outlined,
                    label: isDuplicateSuggestion
                        ? l10n.eventReportQueueDuplicateSuggestion
                        : hasSuggestedEdits
                        ? 'Edit suggestion'
                        : 'Photo suggestion',
                  ),
              ],
            ),
            if (report.details?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              SelectableText.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Additional details: ',
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                    TextSpan(text: report.details!),
                  ],
                ),
              ),
            ],
            if (isDuplicateSuggestion &&
                report.duplicateOfEventId?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push(
                  '/event/${report.duplicateOfEventId!.trim()}',
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.eventReportQueueOpenOriginalEvent),
              ),
              if (report.duplicateOfEventTitle?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    report.duplicateOfEventTitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            if (report.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(report.description!, style: theme.textTheme.bodyMedium),
            ],
            if (report.websiteUrl?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              SelectableText(
                report.websiteUrl!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (hasSuggestedEdits) ...[
              const SizedBox(height: 12),
              EventSuggestedEditsSummary(
                report: report,
                compactMap: true,
              ),
            ],
            if (!isSuggestion &&
                report.latitude != null &&
                report.longitude != null) ...[
              const SizedBox(height: 12),
              Text(
                'Proposed location',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              LocationReviewMap(
                suggested: LatLng(report.latitude!, report.longitude!),
                height: 180,
                showSatelliteToggle: false,
                interactive: false,
              ),
            ],
            if (report.suggestedPhotoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Suggested photos',
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
                    width: 120,
                    height: 120,
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
            ],
            if (report.moderatorNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Moderator notes: ${report.moderatorNotes!}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (isBusy) ...[
              if (busyProgressLabel != null) ...[
                ImageProcessingBanner(message: busyProgressLabel!),
                const SizedBox(height: 12),
              ],
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (canReview) ...[
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment(value: 'New', label: Text('New')),
                    ButtonSegment(value: 'Reviewing', label: Text('Reviewing')),
                  ],
                  selected: {
                    report.status == 'Reviewing' ? 'Reviewing' : 'New',
                  },
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) onSetStatus(selection.first);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          isDuplicateSuggestion
                              ? l10n.eventReportQueueApproveDuplicate
                              : isSuggestion
                              ? 'Approve suggestion'
                              : 'Approve & publish',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ] else if (report.approvedEventId != null) ...[
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/event/${report.approvedEventId}'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    isSuggestion
                        ? 'Open updated event'
                        : 'Open published event',
                  ),
                ),
              ] else if (report.status == 'Rejected') ...[
                OutlinedButton.icon(
                  onPressed: () => onSetStatus('Reviewing'),
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('Move back to reviewing'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
