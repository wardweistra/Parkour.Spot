import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/event_report.dart';
import '../../services/auth_service.dart';
import '../../services/event_report_service.dart';
import '../../utils/event_schedule_utils.dart';
import '../../widgets/page_scaffold.dart';

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

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventReportService>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();
    return PageScaffold(
      title: 'Event Report Queue',
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
            'Review user-submitted event proposals and decide whether to publish them.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<EventReport>>(
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
              stream: service.watchEventReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildMessage(
                    icon: Icons.error_outline,
                    title: 'Failed to load event reports',
                    message: 'Please try again shortly.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
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
    setState(() => _busyReportIds.add(report.id));
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final userId = user?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() => _busyReportIds.remove(report.id));
      }
      return;
    }

    final eventId = await context.read<EventReportService>().approveReport(
      reportId: report.id,
      approverUserId: userId,
      approverName:
          auth.userProfile?.displayName ?? user?.displayName ?? user?.email,
    );

    if (!mounted) return;
    setState(() => _busyReportIds.remove(report.id));
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

    setState(() => _busyReportIds.add(report.id));
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final reviewerUserId = user?.uid;
    if (reviewerUserId == null) {
      if (mounted) setState(() => _busyReportIds.remove(report.id));
      return;
    }

    final ok = await context.read<EventReportService>().rejectReport(
      reportId: report.id,
      reviewerUserId: reviewerUserId,
      reviewerName:
          auth.userProfile?.displayName ?? user?.displayName ?? user?.email,
      moderatorNotes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _busyReportIds.remove(report.id));
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
    required this.onSetStatus,
    required this.onApprove,
    required this.onReject,
  });

  final EventReport report;
  final DateFormat dateFormat;
  final bool isBusy;
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
    final color = _statusColor(theme);
    final canReview = report.status == 'New' || report.status == 'Reviewing';
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
            Text(report.title, style: theme.textTheme.titleMedium),
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
              ],
            ),
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
            if (report.moderatorNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Moderator notes: ${report.moderatorNotes!}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (isBusy)
              const Center(child: CircularProgressIndicator())
            else ...[
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
                        label: const Text('Approve & publish'),
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
                  label: const Text('Open published event'),
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
