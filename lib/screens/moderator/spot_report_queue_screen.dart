import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/spot_report.dart';
import '../../services/spot_report_service.dart';
import '../../services/auth_service.dart';

class SpotReportQueueScreen extends StatefulWidget {
  const SpotReportQueueScreen({super.key});

  @override
  State<SpotReportQueueScreen> createState() => _SpotReportQueueScreenState();
}

class _SpotReportQueueScreenState extends State<SpotReportQueueScreen> {
  static const String _allFilter = 'All';
  late final List<String> _filters = <String>[_allFilter, ...SpotReportService.statuses];
  String _selectedFilter = SpotReportService.statuses.first;
  final Set<String> _updatingReportIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final spotReportService = context.read<SpotReportService>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spot Report Queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/moderator'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work through new spot reports, keeping moderators aligned on progress.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<SpotReport>>(
              stream: spotReportService.watchSpotReports(),
              builder: (context, snapshot) {
                final allReports = snapshot.data ?? <SpotReport>[];
                final statusCounts = <String, int>{
                  _allFilter: allReports.length,
                  for (var status in SpotReportService.statuses)
                    status: allReports.where((r) => r.status == status).length,
                };

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    final count = statusCounts[filter] ?? 0;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(filter),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.secondaryContainer
                                      : theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFilter = filter);
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<SpotReport>>(
                stream: spotReportService.watchSpotReports(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildMessage(
                      context,
                      icon: Icons.error_outline,
                      title: 'Failed to load reports',
                      message: 'Please try again shortly.',
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reports = (snapshot.data ?? <SpotReport>[])
                      .where((report) => _selectedFilter == _allFilter || report.status == _selectedFilter)
                      .toList()
                    ..sort((a, b) {
                      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });

                  if (reports.isEmpty) {
                    return _buildMessage(
                      context,
                      icon: Icons.inbox_outlined,
                      title: _selectedFilter == SpotReportService.statuses.first
                          ? 'No new reports'
                          : 'Nothing to review',
                      message: _selectedFilter == SpotReportService.statuses.first
                          ? 'Incoming spot reports will appear here.'
                          : 'Try switching filters to see other reports.',
                    );
                  }

                  return ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final isUpdating = _updatingReportIds.contains(report.id);
                      return _ReportCard(
                        report: report,
                        dateFormat: dateFormat,
                        isUpdating: isUpdating,
                        onChangeStatus: (status) => _changeReportStatus(report, status),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeReportStatus(SpotReport report, String status) async {
    if (_updatingReportIds.contains(report.id)) return;

    setState(() => _updatingReportIds.add(report.id));
    final service = context.read<SpotReportService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final userProfile = authService.userProfile;
    
    final success = await service.updateReportStatus(
      reportId: report.id,
      status: status,
      userId: user?.uid,
      userName: userProfile?.displayName ?? user?.email,
    );

    if (!mounted) return;

    setState(() => _updatingReportIds.remove(report.id));

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text('Report marked as $status.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to update report status to $status.')),
      );
    }
  }

  Widget _buildMessage(
    BuildContext context, {
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
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({
    required this.report,
    required this.dateFormat,
    required this.isUpdating,
    required this.onChangeStatus,
  });

  final SpotReport report;
  final DateFormat dateFormat;
  final bool isUpdating;
  final ValueChanged<String> onChangeStatus;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return widget.dateFormat.format(dateTime.toLocal());
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Color _getStatusColor(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'Done':
        return colorScheme.primary;
      case 'In Progress':
        return colorScheme.tertiary;
      case 'New':
      default:
        return colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(widget.report.status);
    final isNew = widget.report.status == SpotReportService.statuses.first;

    return Card(
      elevation: isNew ? 2 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: isNew ? 0.5 : 0.3),
          width: isNew ? 2 : 1,
        ),
      ),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Spot name (clickable) at top left
              InkWell(
                onTap: () => context.go('/spot/${widget.report.spotId}'),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.report.spotName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Metadata row: category, reporter, time, location
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Report type/category first
                  if (widget.report.displayCategories.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.report.displayCategories.first,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  if (widget.report.reporterName?.isNotEmpty ?? false)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.report.reporterName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  if (widget.report.createdAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(widget.report.createdAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  if (widget.report.locationSummary != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.report.locationSummary!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            if (widget.report.duplicateOfSpotId != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.go('/spot/${widget.report.duplicateOfSpotId}'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open suggested original spot'),
              ),
            ],
            if (widget.report.otherCategory?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    const TextSpan(
                      text: 'Issue Description: ',
                    ),
                    TextSpan(
                      text: widget.report.otherCategory!,
                    ),
                  ],
                ),
              ),
            ],
            if (widget.report.details?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    const TextSpan(
                      text: 'Additional Details: ',
                    ),
                    TextSpan(
                      text: widget.report.details!,
                    ),
                  ],
                ),
              ),
            ],
            if (widget.report.primaryContact != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  final Uri emailUri = Uri.parse('mailto:${widget.report.primaryContact}');
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Contact user'),
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            if (widget.isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: SpotReportService.statuses.map((status) {
                      return ButtonSegment<String>(
                        value: status,
                        label: Text(status),
                      );
                    }).toList(),
                    selected: {widget.report.status},
                    onSelectionChanged: (Set<String> newSelection) {
                      if (newSelection.isNotEmpty) {
                        widget.onChangeStatus(newSelection.first);
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}


