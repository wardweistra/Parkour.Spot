import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';

import '../../models/spot_report.dart';
import '../../services/spot_report_service.dart';
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/photo_approval_dialog.dart';
import '../../widgets/edit_suggestion_approval_dialog.dart';
import '../../widgets/page_scaffold.dart';

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

    return PageScaffold(
      title: 'Spot Report Queue',
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
              'Review user-submitted spot reports here. Mark reports as "Reviewing" when you start working on them to prevent duplicate efforts, and mark them as "Done" when complete.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<SpotReport>>(
              initialData: spotReportService.latestSpotReports,
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
                initialData: spotReportService.latestSpotReports,
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

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
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
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
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

  Future<void> _handleReviewPhotos(BuildContext context, SpotReport report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PhotoApprovalDialog(
        report: report,
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo review completed.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleApplyEditSuggestions(
      BuildContext context, SpotReport report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EditSuggestionApprovalDialog(
        report: report,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit suggestions applied successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleUndoRejection(BuildContext context, SpotReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo Rejection'),
        content: const Text('This will restore the rejected photos back to suggestions. They will appear in the queue again for review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.primary,
            ),
            child: const Text('Undo Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final spotService = Provider.of<SpotService>(context, listen: false);
      final reportService = Provider.of<SpotReportService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // Move photos from /rejected/ back to /suggestions/
      if (report.rejectedPhotoUrls != null && report.rejectedPhotoUrls!.isNotEmpty) {
        // Store original rejected URLs before moving
        final originalRejectedUrls = List<String>.from(report.rejectedPhotoUrls!);
        final restoredUrls = await spotService.movePhotosFromRejectedToSuggestions(originalRejectedUrls);
        
        if (restoredUrls.isNotEmpty) {
          // Update report to move photos back to suggestedPhotoUrls
          // Pass both original rejected URLs (to remove from rejectedPhotoUrls) and new suggested URLs (to add to suggestedPhotoUrls)
          await reportService.undoPhotoRejection(
            reportId: report.id,
            originalRejectedUrls: originalRejectedUrls,
            restoredPhotoUrls: restoredUrls,
            userId: authService.currentUser?.uid,
            userName: authService.userProfile?.displayName ?? authService.currentUser?.email,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rejection undone. Photos restored to suggestions.'),
          backgroundColor: Colors.green,
        ),
      );
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
                onTap: () {
                  final url = UrlService.generateNavigationUrl(
                    widget.report.spotId,
                    countryCode: widget.report.spotCountryCode,
                    city: widget.report.spotCity,
                  );
                  context.push(url);
                },
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
              // Metadata row: category, reporter, time, location, report ID
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
                  // Report ID (selectable, last)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      SelectableText(
                        'ID: ${widget.report.id}',
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
                onPressed: () {
                  // For duplicate spots, we don't have countryCode/city info,
                  // so this will fall back to /spot/<id> format
                  final url = UrlService.generateNavigationUrl(widget.report.duplicateOfSpotId!);
                  context.push(url);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open suggested original spot'),
              ),
            ],
            if (widget.report.otherCategory?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              SelectableText.rich(
                TextSpan(
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
              SelectableText.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Additional Details: ',
                      style: TextStyle(
                        color: colorScheme.secondary,
                      ),
                    ),
                    TextSpan(
                      text: widget.report.details!,
                    ),
                  ],
                ),
              ),
            ],
            if (widget.report.moderatorNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              SelectableText.rich(
                TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Moderator Comment: ',
                      style: TextStyle(
                        color: colorScheme.secondary,
                      ),
                    ),
                    TextSpan(
                      text: widget.report.moderatorNotes!,
                    ),
                  ],
                ),
              ),
            ],
            // Accepted photos (if any)
            if (widget.report.acceptedPhotoUrls != null && widget.report.acceptedPhotoUrls!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Accepted Photos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.report.acceptedPhotoUrls!.map((photoUrl) {
                  return GestureDetector(
                    onTap: () {
                      // Show full-size image in a dialog
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.contain,
                                  imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            // Overlay to indicate accepted status
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Edit suggestions summary
            if (widget.report.hasEditSuggestions) ...[
              const SizedBox(height: 12),
              Text(
                'Fields with suggested changes',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.report.suggestedName != null)
                    Chip(
                      label: const Text('Title'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedDescription != null)
                    Chip(
                      label: const Text('Description'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedLatitude != null &&
                      widget.report.suggestedLongitude != null)
                    Chip(
                      label: const Text('Location'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedGoodFor != null &&
                      widget.report.suggestedGoodFor!.isNotEmpty)
                    Chip(
                      label: const Text('Good for'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedSpotFeatures != null &&
                      widget.report.suggestedSpotFeatures!.isNotEmpty)
                    Chip(
                      label: const Text('Features'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedSpotAccess != null)
                    Chip(
                      label: const Text('Access'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.report.suggestedSpotFacilities != null &&
                      widget.report.suggestedSpotFacilities!.isNotEmpty)
                    Chip(
                      label: const Text('Facilities'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Photo suggestions
            if (widget.report.suggestedPhotoUrls != null && widget.report.suggestedPhotoUrls!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Suggested Photos',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.report.suggestedPhotoUrls!.map((photoUrl) {
                  return GestureDetector(
                    onTap: () {
                      // Show full-size image in a dialog
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.contain,
                                  imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outline,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Rejected photos (if any)
            if (widget.report.rejectedPhotoUrls != null && widget.report.rejectedPhotoUrls!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rejected Photos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.report.rejectedPhotoUrls!.map((photoUrl) {
                  return GestureDetector(
                    onTap: () {
                      // Show full-size image in a dialog
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.contain,
                                  imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.error,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
                              placeholder: (context, url) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            // Overlay to indicate rejected status
                            Container(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              child: Icon(
                                Icons.cancel_outlined,
                                color: colorScheme.error,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (widget.report.primaryContact != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        // Build email subject
                        final subject = 'Re: Spot Report - ${widget.report.spotName}';
                        
                        // Build email body with report details
                        final bodyParts = <String>[];
                        bodyParts.add('Hello,');
                        bodyParts.add('');
                        bodyParts.add('Thank you for your spot report. Here are the details:');
                        bodyParts.add('');
                        bodyParts.add('Spot: ${widget.report.spotName}');
                        if (widget.report.locationSummary != null) {
                          bodyParts.add('Location: ${widget.report.locationSummary}');
                        }
                        bodyParts.add('Report ID: ${widget.report.id}');
                        if (widget.report.displayCategories.isNotEmpty) {
                          bodyParts.add('Category: ${widget.report.displayCategories.join(", ")}');
                        }
                        if (widget.report.otherCategory?.isNotEmpty ?? false) {
                          bodyParts.add('');
                          bodyParts.add('Issue Description:');
                          bodyParts.add(widget.report.otherCategory!);
                        }
                        if (widget.report.details?.isNotEmpty ?? false) {
                          bodyParts.add('');
                          bodyParts.add('Additional Details:');
                          bodyParts.add(widget.report.details!);
                        }
                        if (widget.report.moderatorNotes?.isNotEmpty ?? false) {
                          bodyParts.add('');
                          bodyParts.add('Moderator Comment:');
                          bodyParts.add(widget.report.moderatorNotes!);
                        }
                        bodyParts.add('');
                        bodyParts.add('Best regards,');
                        
                        final body = bodyParts.join('\n');
                        
                        // Create mailto URI with subject and body
                        final emailUri = Uri(
                          scheme: 'mailto',
                          path: widget.report.primaryContact,
                          queryParameters: {
                            'subject': subject,
                            'body': body,
                          },
                        );
                        
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      },
                      icon: const Icon(Icons.email, size: 18),
                      label: const Text('Email user'),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.report.primaryContact!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email address copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy email address',
                  ),
                ],
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
                  // Edit suggestion actions
                  if (widget.report.hasEditSuggestions) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleApplyEditSuggestions(context, widget.report),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Review Edit Suggestions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Photo suggestion actions
                  if (widget.report.suggestedPhotoUrls != null && widget.report.suggestedPhotoUrls!.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: () => _handleReviewPhotos(context, widget.report),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Review Suggested Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Undo rejection button (if photos were rejected)
                  if (widget.report.rejectedPhotoUrls != null && widget.report.rejectedPhotoUrls!.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: () => _handleUndoRejection(context, widget.report),
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo Rejection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Status selector
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


