import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import '../models/spot_report.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/auth_service.dart';
import '../services/spot_report_service.dart';

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
  Spot? _currentSpot;
  bool _isLoadingOriginalSpot = false;
  bool _isSpotFromSource = false;
  final TextEditingController _notesController = TextEditingController();
  Set<int> _selectedPhotoIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _targetSpotId = widget.report.spotId;
    _selectedPhotoIndices = Set<int>.from(
      List<int>.generate(_suggestedPhotoUrls.length, (index) => index),
    );
    _loadSpotAndCheckSource();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSpotAndCheckSource() async {
    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spot = await spotService.getSpotById(widget.report.spotId);
      
      if (spot == null) {
        if (mounted) {
          setState(() {
            _isLoadingOriginalSpot = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentSpot = spot;
          _isSpotFromSource = spot.spotSource != null && spot.spotSource!.isNotEmpty;
          _isLoadingOriginalSpot = true;
        });
      }

      // If spot is a duplicate, load the original spot
      if (spot.duplicateOf != null) {
        final originalSpot = await spotService.getSpotById(spot.duplicateOf!);
        
        if (mounted) {
          setState(() {
            _originalSpot = originalSpot;
            _isLoadingOriginalSpot = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingOriginalSpot = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading spot: $e');
      if (mounted) {
        setState(() {
          _isLoadingOriginalSpot = false;
        });
      }
    }
  }

  bool get _isTargetSpotFromSource {
    // If target spot is the original spot, check if it's from a source
    if (_targetSpotId != null && _targetSpotId != widget.report.spotId && _originalSpot != null) {
      return _originalSpot!.spotSource != null && _originalSpot!.spotSource!.isNotEmpty;
    }
    // Otherwise check the current spot
    return _isSpotFromSource;
  }

  bool get _isTargetSpotDuplicate {
    // If target spot is the current spot, check if it's a duplicate
    if (_targetSpotId == widget.report.spotId) {
      return _currentSpot?.duplicateOf != null && _currentSpot!.duplicateOf!.isNotEmpty;
    }
    // If target spot is the original spot, it's not a duplicate
    return false;
  }

  bool get _canApprovePhotos {
    // Cannot approve if target spot is from a source or is a duplicate
    return !_isTargetSpotFromSource && !_isTargetSpotDuplicate;
  }

  Spot? get _targetSpot {
    if (_targetSpotId != null && _targetSpotId != widget.report.spotId && _originalSpot != null) {
      return _originalSpot;
    }
    return _currentSpot;
  }

  List<String> get _suggestedPhotoUrls => widget.report.suggestedPhotoUrls ?? const <String>[];

  bool get _hasSelectedPhotos => _selectedPhotoIndices.isNotEmpty;

  void _togglePhotoSelection(int index) {
    if (_isApproving) return;

    setState(() {
      if (_selectedPhotoIndices.contains(index)) {
        _selectedPhotoIndices.remove(index);
      } else {
        _selectedPhotoIndices.add(index);
      }
    });
  }

  void _selectAllPhotos() {
    if (_isApproving) return;
    setState(() {
      _selectedPhotoIndices = Set<int>.from(
        List<int>.generate(_suggestedPhotoUrls.length, (index) => index),
      );
    });
  }

  void _clearSelectedPhotos() {
    if (_isApproving) return;
    setState(() {
      _selectedPhotoIndices.clear();
    });
  }

  void _showPhotoPreview(String photoUrl) {
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
  }

  Future<void> _approvePhotos() async {
    final suggestedPhotoUrls = _suggestedPhotoUrls;
    if (suggestedPhotoUrls.isEmpty) {
      setState(() {
        _error = 'No photos to approve';
      });
      return;
    }

    if (!_hasSelectedPhotos) {
      setState(() {
        _error = 'Select at least one photo to approve';
      });
      return;
    }

    // Prevent approval if target spot is from a spot source
    if (_isTargetSpotFromSource) {
      final targetSpot = _targetSpot;
      final sourceName = targetSpot?.spotSourceName ?? 'external source';
      setState(() {
        _error = 'Photos cannot be approved for spots from external sources ($sourceName). Please create a native spot first.';
      });
      return;
    }

    // Prevent approval if target spot is a duplicate
    if (_isTargetSpotDuplicate) {
      setState(() {
        _error = 'Photos cannot be approved for duplicate spots. Please approve photos to the original spot instead.';
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

      // Use reporter's information for contributors list
      final userId = widget.report.reporterUserId;
      final userName = widget.report.reporterName;

      // Use moderator's information for audit log
      final approvedByUserId = authService.currentUser?.uid;
      final approvedByUserName = authService.userProfile?.displayName ??
          authService.currentUser?.displayName ??
          authService.currentUser?.email;

      final sortedSelectedIndices = _selectedPhotoIndices.toList()..sort();
      final originalPhotoUrls = sortedSelectedIndices
          .map((index) => suggestedPhotoUrls[index])
          .toList(growable: false);
      final approvedAllSuggestedPhotos = originalPhotoUrls.length == suggestedPhotoUrls.length;

      // Add photos to the target spot (returns new URLs from /spots/)
      final approvedPhotoUrls = await spotService.addPhotosToSpot(
        spotId: widget.report.spotId,
        photoUrls: originalPhotoUrls,
        userId: userId,
        userName: userName,
        reportId: widget.report.id,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        targetSpotId: _targetSpotId,
        approvedByUserId: approvedByUserId,
        approvedByUserName: approvedByUserName,
      );

      if (!mounted) return;

      if (approvedPhotoUrls != null && approvedPhotoUrls.isNotEmpty) {
        // Update report by moving only selected photos from suggested -> accepted
        final updatedReport = await reportService.updateReportWithApprovedPhotos(
          reportId: widget.report.id,
          originalPhotoUrls: originalPhotoUrls,
          approvedPhotoUrls: approvedPhotoUrls,
          userId: userId,
          userName: userName,
        );

        if (!updatedReport) {
          setState(() {
            _error = 'Failed to update report after approving photos';
            _isApproving = false;
          });
          return;
        }

        // Only mark as Done if all currently suggested photos were approved.
        if (approvedAllSuggestedPhotos) {
          await reportService.updateReportStatus(
            reportId: widget.report.id,
            status: 'Done',
            userId: userId,
            userName: userName,
          );
        }

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

    return PopScope(
      canPop: !_isApproving,
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
                if (_suggestedPhotoUrls.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Photos to Add',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedPhotoIndices.length}/${_suggestedPhotoUrls.length} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a photo to include or exclude it from approval.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _isApproving ? null : _selectAllPhotos,
                        icon: const Icon(Icons.select_all),
                        label: const Text('Select all'),
                      ),
                      TextButton.icon(
                        onPressed: _isApproving ? null : _clearSelectedPhotos,
                        icon: const Icon(Icons.remove_done),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedPhotoUrls.asMap().entries.map((entry) {
                      final index = entry.key;
                      final photoUrl = entry.value;
                      final isSelected = _selectedPhotoIndices.contains(index);

                      return GestureDetector(
                        onTap: () => _togglePhotoSelection(index),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outline,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
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
                                if (!isSelected)
                                  Container(
                                    color: colorScheme.surface.withValues(alpha: 0.45),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                    size: 22,
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: IconButton(
                                    onPressed: () => _showPhotoPreview(photoUrl),
                                    icon: const Icon(Icons.zoom_out_map, size: 16),
                                    tooltip: 'Preview full size',
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                                      padding: const EdgeInsets.all(4),
                                      minimumSize: const Size(28, 28),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                // Warning if target spot is from a spot source
                if (_isTargetSpotFromSource) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.error,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.onErrorContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cannot Approve Photos',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The selected spot is from an external source (${_targetSpot?.spotSourceName ?? "external source"}). '
                                'Photos can only be approved for native spots.\n\n'
                                'To approve these photos, please first create a native spot from this spot. '
                                'You can do this by viewing the spot details and selecting "Create Native Spot" from the menu.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Warning if target spot is a duplicate
                if (_isTargetSpotDuplicate) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.error,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.onErrorContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cannot Approve Photos',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The selected spot is a duplicate of another spot. '
                                'Photos can only be approved for the original spot, not duplicates.\n\n'
                                'Please select the original spot below to approve these photos.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  RadioGroup<String>(
                    groupValue: _targetSpotId,
                    onChanged: (String? value) {
                      // Check if the selected value should be disabled
                      final isCurrentSpotDisabled = _isApproving || _isSpotFromSource || (_currentSpot?.duplicateOf != null && _currentSpot!.duplicateOf!.isNotEmpty);
                      final isOriginalSpotDisabled = _isApproving || (_originalSpot!.spotSource != null && _originalSpot!.spotSource!.isNotEmpty);
                      
                      if (value == widget.report.spotId && isCurrentSpotDisabled) {
                        return; // Don't allow selection of disabled current spot
                      }
                      if (value == _originalSpot!.id && isOriginalSpotDisabled) {
                        return; // Don't allow selection of disabled original spot
                      }
                      
                      setState(() {
                        _targetSpotId = value;
                      });
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Current spot: ${widget.report.spotName}'),
                          subtitle: (_currentSpot?.duplicateOf != null && _currentSpot!.duplicateOf!.isNotEmpty)
                              ? Text('The reported spot (duplicate of ${_originalSpot?.name ?? "another spot"})')
                              : _isSpotFromSource
                                  ? Text('The reported spot (from ${_currentSpot?.spotSourceName ?? "external source"})')
                                  : const Text('The reported spot'),
                          value: widget.report.spotId,
                          enabled: !(_isApproving || _isSpotFromSource || (_currentSpot?.duplicateOf != null && _currentSpot!.duplicateOf!.isNotEmpty)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          title: Text('Original spot: ${_originalSpot!.name}'),
                          subtitle: Text(_originalSpot!.spotSource != null && _originalSpot!.spotSource!.isNotEmpty
                              ? 'The original spot (from ${_originalSpot!.spotSourceName ?? "external source"})'
                              : 'The original spot (recommended)'),
                          value: _originalSpot!.id!,
                          enabled: !(_isApproving || (_originalSpot!.spotSource != null && _originalSpot!.spotSource!.isNotEmpty)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
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
            onPressed: (_isApproving || !_canApprovePhotos || !_hasSelectedPhotos)
                ? null
                : _approvePhotos,
            child: _isApproving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Approve Selected (${_selectedPhotoIndices.length})'),
          ),
        ],
      ),
    );
  }
}

