import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/spot_report.dart';
import '../services/spot_report_service.dart';

/// Reusable widget for moderator action dialogs that includes:
/// - Optional spot report selector dropdown
/// - Optional notes text field
class ModeratorActionFields extends StatefulWidget {
  final String? spotId;
  final TextEditingController notesController;
  final ValueChanged<String?> onReportSelected;
  final bool showReportSelector;

  const ModeratorActionFields({
    super.key,
    required this.spotId,
    required this.notesController,
    required this.onReportSelected,
    this.showReportSelector = true,
  });

  @override
  State<ModeratorActionFields> createState() => _ModeratorActionFieldsState();
}

class _ModeratorActionFieldsState extends State<ModeratorActionFields> {
  List<SpotReport>? _spotReports;
  String? _selectedReportId;
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    if (widget.showReportSelector && widget.spotId != null) {
      _loadSpotReports();
    }
  }

  Future<void> _loadSpotReports() async {
    if (widget.spotId == null) return;
    
    setState(() => _isLoadingReports = true);
    try {
      final spotReportService = Provider.of<SpotReportService>(context, listen: false);
      final reports = await spotReportService.getReportsForSpot(widget.spotId!);
      if (mounted) {
        setState(() {
          _spotReports = reports;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsList = _spotReports ?? <SpotReport>[];
    final hasReports = reportsList.isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showReportSelector) ...[
          const Text(
            'Optionally link this action to a spot report:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_isLoadingReports)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedReportId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select a report (optional)',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: hasReports ? null : 'No spot reports available for this spot',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None'),
                ),
                if (hasReports)
                  ...reportsList.map((report) {
                  final categories = report.displayCategories.join(', ');
                  final dateStr = report.createdAt != null
                      ? DateFormat('MMM d, y').format(report.createdAt!.toLocal())
                      : '';
                  final reporterInfo = report.reporterName?.isNotEmpty == true
                      ? report.reporterName!
                      : report.reporterEmail?.isNotEmpty == true
                          ? report.reporterEmail!
                          : 'Anonymous';
                  // Check if this report mentions the current spot as the original (duplicate report)
                  final isDuplicateReport = report.duplicateOfSpotId == widget.spotId;
                  return DropdownMenuItem<String>(
                    value: report.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                categories,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isDuplicateReport) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Original',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'By $reporterInfo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                  }),
              ],
              selectedItemBuilder: (context) {
                if (!hasReports) {
                  return [
                    Text(
                      'No reports available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ];
                }
                return [
                  const Text('None'),
                  ...reportsList.map((report) {
                    final categories = report.displayCategories.firstOrNull ?? 'Report';
                    final reporterInfo = report.reporterName?.isNotEmpty == true
                        ? report.reporterName!
                        : report.reporterEmail?.isNotEmpty == true
                            ? report.reporterEmail!
                            : 'Anonymous';
                    final isDuplicateReport = report.duplicateOfSpotId == widget.spotId;
                    final suffix = isDuplicateReport ? ' • Original' : '';
                    return Text(
                      '$categories • By $reporterInfo$suffix',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    );
                  }),
                ];
              },
              onChanged: hasReports ? (value) {
                setState(() {
                  _selectedReportId = value;
                });
                widget.onReportSelected(value);
              } : null,
            ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: widget.notesController,
          decoration: const InputDecoration(
            labelText: 'Additional notes (optional)',
            hintText: 'Provide any additional context for this action...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

