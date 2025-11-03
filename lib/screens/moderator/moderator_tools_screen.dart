import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/spot_report.dart';
import '../../services/auth_service.dart';
import '../../services/spot_report_service.dart';

class ModeratorToolsScreen extends StatefulWidget {
  const ModeratorToolsScreen({super.key});

  @override
  State<ModeratorToolsScreen> createState() => _ModeratorToolsScreenState();
}

class _ModeratorToolsScreenState extends State<ModeratorToolsScreen> {
  static const String _allFilter = 'All';
  late final List<String> _filters = <String>[_allFilter, ...SpotReportService.statuses];
  String _selectedFilter = SpotReportService.statuses.first;
  final Set<String> _updatingReportIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (!authService.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderator Tools')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Sign in required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Moderator tools are available after signing in.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/login?redirectTo=${Uri.encodeComponent('/moderator')}'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderator Tools')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Moderator access required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask an administrator to grant you moderator permissions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spotReportService = context.read<SpotReportService>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Tools'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home?tab=profile'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spot Report Queue',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Work through new spot reports, keeping moderators aligned on progress.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                    }
                  },
                );
              }).toList(),
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
                      return aTime.compareTo(bTime);
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
    final success = await service.updateReportStatus(reportId: report.id, status: status);

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

class _ReportCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.spotName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.spotId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 4),
                Text(
                  report.createdAt != null ? dateFormat.format(report.createdAt!.toLocal()) : 'Awaiting timestamp',
                  style: theme.textTheme.bodySmall,
                ),
                if (report.locationSummary != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    report.locationSummary!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.displayCategories
                  .map((category) => Chip(
                        label: Text(category),
                        backgroundColor: colorScheme.secondaryContainer,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ))
                  .toList(),
            ),
            if (report.details?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Details',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                report.details!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (report.primaryContact != null) ...[
              const SizedBox(height: 12),
              Text(
                'Contact',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(
                report.primaryContact!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/spot/${report.spotId}'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Spot'),
                  ),
                  if (report.status != SpotReportService.statuses.first)
                    OutlinedButton(
                      onPressed: () => onChangeStatus(SpotReportService.statuses.first),
                      child: const Text('Mark as New'),
                    ),
                  if (report.status != SpotReportService.statuses[1])
                    OutlinedButton(
                      onPressed: () => onChangeStatus(SpotReportService.statuses[1]),
                      child: const Text('Mark In Progress'),
                    ),
                  if (report.status != SpotReportService.statuses.last)
                    FilledButton(
                      onPressed: () => onChangeStatus(SpotReportService.statuses.last),
                      child: const Text('Mark Done'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    switch (status) {
      case 'Done':
        statusColor = colorScheme.primary;
        break;
      case 'In Progress':
        statusColor = colorScheme.tertiary;
        break;
      case 'New':
      default:
        statusColor = colorScheme.secondary;
        break;
    }

    return Chip(
      label: Text(status),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor),
      backgroundColor: statusColor.withValues(alpha: 0.15),
      side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
    );
  }
}
