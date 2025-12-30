import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot_report.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/auth_service.dart';
import '../services/spot_report_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class PhotoApprovalDialog extends StatefulWidget {
  final SpotReport report;

  const PhotoApprovalDialog({
    super.key,
    required this.report,
  });

  @override
  State<PhotoApprovalDialog> createState() => _PhotoApprovalDialogState();
}

class _PhotoApprovalDialogState extends State<PhotoApprovalDialog> {
  String? _targetSpotId;
  bool _isApproving = false;
  String? _error;
  Spot? _originalSpot;
  bool _isLoadingOriginalSpot = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetSpotId = widget.report.spotId;
    _loadOriginalSpotIfDuplicate();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOriginalSpotIfDuplicate() async {
    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spot = await spotService.getSpotById(widget.report.spotId);
      
      if (spot != null && spot.duplicateOf != null && mounted) {
        setState(() {
          _isLoadingOriginalSpot = true;
        });

        final originalSpot = await spotService.getSpotById(spot.duplicateOf!);
        
        if (mounted) {
          setState(() {
            _originalSpot = originalSpot;
            _isLoadingOriginalSpot = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading original spot: $e');
      if (mounted) {
        setState(() {
          _isLoadingOriginalSpot = false;
        });
      }
    }
  }

  Future<void> _approvePhotos() async {
    if (widget.report.suggestedPhotoUrls == null || widget.report.suggestedPhotoUrls!.isEmpty) {
      setState(() {
        _error = 'No photos to approve';
      });
      return;
    }

    setState(() {
      _isApproving = true;
      _error = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final reportService = Provider.of<SpotReportService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final userId = authService.currentUser?.uid;
      final userName = authService.userProfile?.displayName ??
          authService.currentUser?.displayName ??
          authService.currentUser?.email;

      // Store original URLs before moving
      final originalPhotoUrls = List<String>.from(widget.report.suggestedPhotoUrls!);

      // Add photos to the target spot (returns new URLs from /spots/)
      final approvedPhotoUrls = await spotService.addPhotosToSpot(
        spotId: widget.report.spotId,
        photoUrls: originalPhotoUrls,
        userId: userId,
        userName: userName,
        reportId: widget.report.id,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        targetSpotId: _targetSpotId,
      );

      if (!mounted) return;

      if (approvedPhotoUrls != null && approvedPhotoUrls.isNotEmpty) {
        // Update report with approved photo URLs (replace suggestedPhotoUrls with new /spots/ URLs)
        await reportService.updateReportWithApprovedPhotos(
          reportId: widget.report.id,
          originalPhotoUrls: originalPhotoUrls,
          approvedPhotoUrls: approvedPhotoUrls,
          userId: userId,
          userName: userName,
        );

        // Mark report as Done
        await reportService.updateReportStatus(
          reportId: widget.report.id,
          status: 'Done',
          userId: userId,
          userName: userName,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = spotService.error ?? 'Failed to add photos to spot';
          _isApproving = false;
        });
      }
    } catch (e) {
      debugPrint('Error approving photos: $e');
      if (mounted) {
        setState(() {
          _error = 'Error approving photos: $e';
          _isApproving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async => !_isApproving,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_photo_alternate, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Approve Photo Suggestions')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo previews
                if (widget.report.suggestedPhotoUrls != null && widget.report.suggestedPhotoUrls!.isNotEmpty) ...[
                  Text(
                    'Photos to Add',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.report.suggestedPhotoUrls!.map((photoUrl) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    child: CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      fit: BoxFit.contain,
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
                  const SizedBox(height: 16),
                ],
                // Target spot selection (if spot is duplicate)
                if (_isLoadingOriginalSpot)
                  const Center(child: CircularProgressIndicator())
                else if (_originalSpot != null) ...[
                  Text(
                    'Target Spot',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: Text('Current spot: ${widget.report.spotName}'),
                    subtitle: const Text('The reported spot'),
                    value: widget.report.spotId,
                    groupValue: _targetSpotId,
                    onChanged: _isApproving ? null : (value) {
                      setState(() {
                        _targetSpotId = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: Text('Original spot: ${_originalSpot!.name}'),
                    subtitle: const Text('The original spot (recommended)'),
                    value: _originalSpot!.id!,
                    groupValue: _targetSpotId,
                    onChanged: _isApproving ? null : (value) {
                      setState(() {
                        _targetSpotId = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                ],
                // Notes field
                Text(
                  'Notes (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add notes about this approval...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                  enabled: !_isApproving,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isApproving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isApproving ? null : _approvePhotos,
            child: _isApproving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

