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
  String? _approvalProgress; // e.g. "Processing 2 of 5..."
  String? _error;
  Spot? _originalSpot;
  Spot? _currentSpot;
  bool _isLoadingOriginalSpot = false;
  bool _isSpotFromSource = false;
  final TextEditingController _notesController = TextEditingController();
  final Map<int, bool> _accepted = {}; // index -> true=accept, false=reject

  @override
  void initState() {
    super.initState();
    _targetSpotId = widget.report.spotId;
    for (var i = 0; i < (_suggestedPhotoUrls.length); i++) {
      _accepted[i] = true;
    }
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

  Spot? get _targetSpot {
    if (_targetSpotId != null && _targetSpotId != widget.report.spotId && _originalSpot != null) {
      return _originalSpot;
    }
    return _currentSpot;
  }

  List<String> get _suggestedPhotoUrls => widget.report.suggestedPhotoUrls ?? const <String>[];

  List<int> get _acceptedIndices =>
      _accepted.entries.where((e) => e.value).map((e) => e.key).toList();
  List<int> get _rejectedIndices =>
      _accepted.entries.where((e) => !e.value).map((e) => e.key).toList();

  bool _canSubmit() {
    if (_isApproving) return false;
    return _accepted.isNotEmpty;
  }

  bool _isRejectAll() =>
      !_accepted.values.any((v) => v) && _accepted.isNotEmpty;

  bool _hasApprovedPhotos() => _accepted.values.any((v) => v);

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

  Future<void> _submitReview() async {
    if (!_canSubmit()) return;

    final suggestedPhotoUrls = _suggestedPhotoUrls;
    if (suggestedPhotoUrls.isEmpty) return;

    final moderatorNotes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    // If any approved: need valid target
    if (_hasApprovedPhotos()) {
      if (_isTargetSpotFromSource) {
        final targetSpot = _targetSpot;
        final sourceName = targetSpot?.spotSourceName ?? 'external source';
        setState(() {
          _error =
              'Photos cannot be approved for spots from external sources ($sourceName). '
              'Please create a native spot first.';
        });
        return;
      }
      if (_isTargetSpotDuplicate) {
        setState(() {
          _error =
              'Photos cannot be approved for duplicate spots. '
              'Please select the original spot below.';
        });
        return;
      }
    }

    setState(() {
      _isApproving = true;
      _approvalProgress = null;
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

      final approvedIndices = _acceptedIndices;
      final rejectedIndices = _rejectedIndices;

      // 1. Approved: add to spot
      if (approvedIndices.isNotEmpty && !_isTargetSpotFromSource && !_isTargetSpotDuplicate) {
        final sortedApproved = approvedIndices.toList()..sort();
        final approvedOriginalUrls = sortedApproved
            .map((i) => suggestedPhotoUrls[i])
            .toList(growable: false);

        final approvedPhotoUrls = await spotService.addPhotosToSpot(
          spotId: widget.report.spotId,
          photoUrls: approvedOriginalUrls,
          userId: widget.report.reporterUserId,
          userName: widget.report.reporterName,
          reportId: widget.report.id,
          notes: moderatorNotes,
          targetSpotId: _targetSpotId,
          approvedByUserId: userId,
          approvedByUserName: userName,
          onProgress: (current, total) {
            if (!mounted) return;
            setState(() {
              _approvalProgress = 'Processing $current of $total...';
            });
          },
        );

        if (!mounted) return;

        if (approvedPhotoUrls == null || approvedPhotoUrls.isEmpty) {
          setState(() {
            _error = spotService.error ?? 'Failed to add photos to spot';
            _isApproving = false;
            _approvalProgress = null;
          });
          return;
        }

        await reportService.updateReportWithApprovedPhotos(
          reportId: widget.report.id,
          originalPhotoUrls: approvedOriginalUrls,
          approvedPhotoUrls: approvedPhotoUrls,
          moderatorNotes: moderatorNotes,
          userId: userId,
          userName: userName,
        );
      }

      if (!mounted) return;

      // 2. Rejected: move to rejected folder
      if (rejectedIndices.isNotEmpty) {
        final rejectedOriginalUrls =
            rejectedIndices.map((i) => suggestedPhotoUrls[i]).toList();
        final rejectedUrls = await spotService.movePhotosToRejected(rejectedOriginalUrls);
        if (rejectedUrls.isNotEmpty) {
          await reportService.updateReportWithRejectedPhotos(
            reportId: widget.report.id,
            spotId: widget.report.spotId,
            originalPhotoUrls: rejectedOriginalUrls,
            rejectedPhotoUrls: rejectedUrls,
            moderatorNotes: moderatorNotes,
            userId: userId,
            userName: userName,
          );
        }
      }

      if (!mounted) return;

      // 3. Mark Done when all suggested photos are processed
      await reportService.updateReportStatus(
        reportId: widget.report.id,
        status: 'Done',
        userId: userId,
        userName: authService.userProfile?.displayName,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error in photo review: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isApproving = false;
          _approvalProgress = null;
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
            const Expanded(child: Text('Review Photo Suggestions')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo previews with Accept/Reject per photo
                if (_suggestedPhotoUrls.isNotEmpty) ...[
                  Text(
                    'Select Accept or Reject for each photo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_acceptedIndices.length} accepted, ${_rejectedIndices.length} rejected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedPhotoUrls.asMap().entries.map((entry) {
                      final index = entry.key;
                      final photoUrl = entry.value;
                      final isAccepted = _accepted[index] ?? true;

                      return Container(
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAccepted
                                ? colorScheme.primary
                                : colorScheme.error,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _showPhotoPreview(photoUrl),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    imageRenderMethodForWeb:
                                        ImageRenderMethodForWeb.HttpGet,
                                    placeholder: (context, url) => Container(
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton.filled(
                                    onPressed: _isApproving
                                        ? null
                                        : () {
                                            if (!isAccepted) {
                                              setState(() =>
                                                  _accepted[index] = true);
                                            }
                                          },
                                    icon: const Icon(Icons.check, size: 18),
                                    style: IconButton.styleFrom(
                                      backgroundColor: isAccepted
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      foregroundColor: isAccepted
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                      minimumSize: const Size(36, 32),
                                    ),
                                    tooltip: 'Accept',
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.filled(
                                    onPressed: _isApproving
                                        ? null
                                        : () {
                                            if (isAccepted) {
                                              setState(() =>
                                                  _accepted[index] = false);
                                            }
                                          },
                                    icon: const Icon(Icons.close, size: 18),
                                    style: IconButton.styleFrom(
                                      backgroundColor: !isAccepted
                                          ? colorScheme.errorContainer
                                          : colorScheme.surfaceContainerHighest,
                                      foregroundColor: !isAccepted
                                          ? colorScheme.onErrorContainer
                                          : colorScheme.onSurface,
                                      minimumSize: const Size(36, 32),
                                    ),
                                    tooltip: 'Reject',
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  'Comment (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Document why you accepted or rejected these suggestions...',
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
            onPressed: (_isApproving || !_canSubmit()) ? null : _submitReview,
            child: _isApproving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      if (_approvalProgress != null) ...[
                        const SizedBox(width: 12),
                        Text(_approvalProgress!),
                      ],
                    ],
                  )
                : Text(_isRejectAll()
                    ? 'Submit Review'
                    : 'Submit Review (${_acceptedIndices.length} accepted)'),
          ),
        ],
      ),
    );
  }
}

