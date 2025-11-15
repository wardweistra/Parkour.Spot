import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/spot_report.dart';
import '../../services/spot_report_service.dart';
import '../../services/spot_service.dart';
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
  bool? _isSpotHidden;
  bool _isLoadingSpot = false;
  bool _isTogglingHidden = false;

  @override
  void initState() {
    super.initState();
    _loadSpotHiddenStatus();
  }

  Future<void> _loadSpotHiddenStatus() async {
    setState(() {
      _isLoadingSpot = true;
    });

    try {
      final spotService = context.read<SpotService>();
      final spot = await spotService.getSpotById(widget.report.spotId);
      if (mounted) {
        setState(() {
          _isSpotHidden = spot?.hidden ?? false;
          _isLoadingSpot = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSpot = false;
        });
      }
    }
  }

  Future<void> _toggleSpotHidden() async {
    if (_isTogglingHidden || _isSpotHidden == null) return;

    setState(() {
      _isTogglingHidden = true;
    });

    try {
      final spotService = context.read<SpotService>();
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      final userProfile = authService.userProfile;

      final newHiddenValue = !_isSpotHidden!;
      final success = await spotService.setSpotHidden(
        widget.report.spotId,
        newHiddenValue,
        userId: user?.uid,
        userName: userProfile?.displayName ?? user?.email,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isSpotHidden = newHiddenValue;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newHiddenValue
                    ? 'Spot hidden from public view'
                    : 'Spot unhidden and visible to public',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${newHiddenValue ? 'hide' : 'unhide'} spot',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating spot visibility'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingHidden = false;
        });
      }
    }
  }

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.report.spotName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_isLoadingSpot)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_isSpotHidden == true)
                            Icon(
                              Icons.visibility_off,
                              size: 18,
                              color: colorScheme.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.report.spotId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: widget.report.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.report.createdAt != null ? widget.dateFormat.format(widget.report.createdAt!.toLocal()) : 'Awaiting timestamp',
                  style: theme.textTheme.bodySmall,
                ),
                if (widget.report.locationSummary != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.report.locationSummary!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.report.displayCategories
                  .map((category) => Chip(
                        label: Text(category),
                        backgroundColor: colorScheme.secondaryContainer,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ))
                  .toList(),
            ),
            if (widget.report.duplicateOfSpotId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.copy_all,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Duplicate of:',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.report.duplicateOfSpotId!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.go('/spot/${widget.report.duplicateOfSpotId}'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
            if (widget.report.details?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                'Details',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.report.details!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (widget.report.primaryContact != null) ...[
              const SizedBox(height: 12),
              Text(
                'Contact',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(
                widget.report.primaryContact!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (widget.isUpdating || _isTogglingHidden)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/spot/${widget.report.spotId}'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Spot'),
                  ),
                  if (_isSpotHidden != null)
                    OutlinedButton.icon(
                      onPressed: _isTogglingHidden ? null : _toggleSpotHidden,
                      icon: Icon(_isSpotHidden! ? Icons.visibility : Icons.visibility_off),
                      label: Text(_isSpotHidden! ? 'Unhide Spot' : 'Hide Spot'),
                      style: _isSpotHidden!
                          ? OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              side: BorderSide(color: colorScheme.error),
                            )
                          : null,
                    ),
                  if (widget.report.status != SpotReportService.statuses.first)
                    OutlinedButton(
                      onPressed: () => widget.onChangeStatus(SpotReportService.statuses.first),
                      child: const Text('Mark as New'),
                    ),
                  if (widget.report.status != SpotReportService.statuses[1])
                    OutlinedButton(
                      onPressed: () => widget.onChangeStatus(SpotReportService.statuses[1]),
                      child: const Text('Mark In Progress'),
                    ),
                  if (widget.report.status != SpotReportService.statuses.last)
                    FilledButton(
                      onPressed: () => widget.onChangeStatus(SpotReportService.statuses.last),
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

