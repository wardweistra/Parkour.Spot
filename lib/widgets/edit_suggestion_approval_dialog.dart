import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/spot.dart';
import '../models/spot_report.dart';
import '../constants/spot_attributes.dart';
import '../services/spot_service.dart';
import '../services/spot_report_service.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';

/// Dialog for moderators to accept or reject individual edit suggestions from a spot report.
class EditSuggestionApprovalDialog extends StatefulWidget {
  final SpotReport report;

  const EditSuggestionApprovalDialog({
    super.key,
    required this.report,
  });

  @override
  State<EditSuggestionApprovalDialog> createState() =>
      _EditSuggestionApprovalDialogState();
}

class _EditSuggestionApprovalDialogState
    extends State<EditSuggestionApprovalDialog> {
  final Map<String, bool> _accepted = {};
  bool _isApplying = false;
  String? _error;

  Spot? _currentSpot;
  Spot? _originalSpot;
  String? _targetSpotId;
  bool _isLoading = true;
  bool _isSatelliteView = false;
  final TextEditingController _notesController = TextEditingController();

  Spot? get _targetSpot {
    if (_targetSpotId != null &&
        _originalSpot != null &&
        _targetSpotId == _originalSpot!.id) {
      return _originalSpot;
    }
    return _currentSpot;
  }

  bool get _isTargetSpotFromSource {
    final target = _targetSpot;
    return target?.spotSource != null && target!.spotSource!.isNotEmpty;
  }

  bool get _isTargetSpotDuplicate {
    if (_targetSpotId == widget.report.spotId) {
      return _currentSpot?.duplicateOf != null &&
          _currentSpot!.duplicateOf!.isNotEmpty;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initAccepted();
    _loadSpots();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spot = await spotService.getSpotById(widget.report.spotId);

      if (spot == null || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      Spot? originalSpot;
      if (spot.duplicateOf != null) {
        originalSpot =
            await spotService.getSpotById(spot.duplicateOf!);
      }

      if (!mounted) return;

      setState(() {
        _currentSpot = spot;
        _originalSpot = originalSpot;
        _isLoading = false;
        if (originalSpot != null) {
          _targetSpotId = originalSpot.id;
        } else {
          _targetSpotId = spot.id;
        }
      });
    } catch (e) {
      debugPrint('Error loading spots for edit suggestions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initAccepted() {
    if (widget.report.suggestedName != null) {
      _accepted['name'] = true;
    }
    if (widget.report.suggestedDescription != null) {
      _accepted['description'] = true;
    }
    if (widget.report.suggestedLatitude != null &&
        widget.report.suggestedLongitude != null) {
      _accepted['location'] = true;
    }
    if (widget.report.suggestedGoodFor != null &&
        widget.report.suggestedGoodFor!.isNotEmpty) {
      _accepted['goodFor'] = true;
    }
    if (widget.report.suggestedSpotFeatures != null &&
        widget.report.suggestedSpotFeatures!.isNotEmpty) {
      _accepted['spotFeatures'] = true;
    }
    if (widget.report.suggestedSpotAccess != null) {
      _accepted['spotAccess'] = true;
    }
    if (widget.report.suggestedSpotFacilities != null &&
        widget.report.suggestedSpotFacilities!.isNotEmpty) {
      _accepted['spotFacilities'] = true;
    }
  }

  bool _canApply() {
    if (!_accepted.values.any((v) => v)) return false;
    if (_targetSpot == null) return false;
    if (_isTargetSpotFromSource) return false;
    if (_isTargetSpotDuplicate) return false;
    return true;
  }

  bool _canSubmit() {
    if (_isLoading || _isApplying) return false;
    final acceptedFields = _accepted.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (acceptedFields.isNotEmpty) return _canApply();
    return _accepted.isNotEmpty;
  }

  bool _isRejectAll() {
    return !_accepted.values.any((v) => v) && _accepted.isNotEmpty;
  }

  Future<void> _apply() async {
    if (!_canSubmit()) return;

    final acceptedFields = _accepted.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final rejectedFields =
        _accepted.entries.where((e) => !e.value).map((e) => e.key).toList();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() {
      _isApplying = true;
      _error = null;
    });

    try {
      final reportService = Provider.of<SpotReportService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      if (acceptedFields.isEmpty) {
        await reportService.updateReportWithEditApprovals(
          reportId: widget.report.id,
          acceptedFields: [],
          rejectedFields: rejectedFields,
          moderatorNotes: notes,
        );
        await reportService.updateReportStatus(
          reportId: widget.report.id,
          status: 'Done',
          userId: authService.currentUser?.uid,
          userName: authService.userProfile?.displayName ??
              authService.currentUser?.displayName,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      final spotService = Provider.of<SpotService>(context, listen: false);
      final geocodingService =
          Provider.of<GeocodingService>(context, listen: false);

      final Map<String, dynamic> updates = {};

      if (acceptedFields.contains('name') && widget.report.suggestedName != null) {
        updates['name'] = widget.report.suggestedName;
      }
      if (acceptedFields.contains('description') &&
          widget.report.suggestedDescription != null) {
        updates['description'] = widget.report.suggestedDescription;
      }
      if (acceptedFields.contains('location') &&
          widget.report.suggestedLatitude != null &&
          widget.report.suggestedLongitude != null) {
        updates['latitude'] = widget.report.suggestedLatitude;
        updates['longitude'] = widget.report.suggestedLongitude;
        final details = await geocodingService.geocodeCoordinatesDetails(
          widget.report.suggestedLatitude!,
          widget.report.suggestedLongitude!,
        );
        updates['address'] = details['address'];
        updates['city'] = details['city'];
        updates['countryCode'] = details['countryCode'];
      }
      if (acceptedFields.contains('goodFor') &&
          widget.report.suggestedGoodFor != null) {
        updates['goodFor'] = widget.report.suggestedGoodFor;
      }
      if (acceptedFields.contains('spotFeatures') &&
          widget.report.suggestedSpotFeatures != null) {
        updates['spotFeatures'] = widget.report.suggestedSpotFeatures;
      }
      if (acceptedFields.contains('spotAccess') &&
          widget.report.suggestedSpotAccess != null) {
        updates['spotAccess'] = widget.report.suggestedSpotAccess;
      }
      if (acceptedFields.contains('spotFacilities') &&
          widget.report.suggestedSpotFacilities != null) {
        updates['spotFacilities'] = widget.report.suggestedSpotFacilities;
      }

      final targetSpot = _targetSpot;
      if (targetSpot == null) {
        setState(() {
          _error = 'Target spot not found';
          _isApplying = false;
        });
        return;
      }

      final success = await spotService.applyEditSuggestions(
        spot: targetSpot,
        updates: updates,
        reporterUserId: widget.report.reporterUserId,
        reporterUserName: widget.report.reporterName,
        reportId: widget.report.id,
        moderatorUserId: authService.currentUser?.uid,
        moderatorUserName: authService.userProfile?.displayName ??
            authService.currentUser?.displayName ??
            authService.currentUser?.email,
        notes: notes,
      );

      if (!mounted) return;

      if (success) {
        await reportService.updateReportWithEditApprovals(
          reportId: widget.report.id,
          acceptedFields: acceptedFields,
          rejectedFields: rejectedFields,
          moderatorNotes: notes,
        );
        await reportService.updateReportStatus(
          reportId: widget.report.id,
          status: 'Done',
          userId: authService.currentUser?.uid,
          userName: authService.userProfile?.displayName ??
              authService.currentUser?.displayName,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _error = spotService.error ?? 'Failed to apply edit suggestions';
          _isApplying = false;
        });
      }
    } catch (e) {
      debugPrint('Error applying edit suggestions: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isApplying = false;
        });
      }
    }
  }

  Widget _buildFieldRow(
    BuildContext context, {
    required String fieldLabel,
    required String fieldKey,
    required Widget currentWidget,
    required Widget suggestedWidget,
  }) {
    final theme = Theme.of(context);
    final accepted = _accepted[fieldKey] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fieldLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Accept')),
                  ButtonSegment(value: false, label: Text('Reject')),
                ],
                selected: {accepted},
                onSelectionChanged: (s) {
                  setState(() => _accepted[fieldKey] = s.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    currentWidget,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    suggestedWidget,
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = widget.report;
    final spot = _targetSpot;

    if (_isLoading || spot == null) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Review Edit Suggestions')),
          ],
        ),
        content: const SizedBox(
          width: 400,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Review Edit Suggestions')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTargetSpotFromSource) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cannot Apply Edit Suggestions',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The selected spot is from an external source (${spot.spotSourceName ?? "external source"}). '
                              'Edit suggestions can only be applied to native spots.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
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
              if (_isTargetSpotDuplicate) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cannot Apply Edit Suggestions',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The selected spot is a duplicate. '
                              'Edit suggestions can only be applied to the original spot.\n\n'
                              'Please select the original spot below.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
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
              if (_originalSpot != null) ...[
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
                    final isCurrentDisabled = _isApplying ||
                        (_currentSpot?.duplicateOf != null &&
                            _currentSpot!.duplicateOf!.isNotEmpty) ||
                        (_currentSpot?.spotSource != null &&
                            _currentSpot!.spotSource!.isNotEmpty);
                    final isOriginalDisabled = _isApplying ||
                        (_originalSpot!.spotSource != null &&
                            _originalSpot!.spotSource!.isNotEmpty);

                    if (value == widget.report.spotId && isCurrentDisabled) return;
                    if (value == _originalSpot!.id && isOriginalDisabled) return;

                    setState(() => _targetSpotId = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: Text(
                            'Reported spot: ${widget.report.spotName}'),
                        subtitle: (_currentSpot?.duplicateOf != null &&
                                _currentSpot!.duplicateOf!.isNotEmpty)
                            ? Text(
                                'The reported spot (duplicate of ${_originalSpot?.name ?? "another spot"})')
                            : _currentSpot?.spotSource != null
                                ? Text(
                                    'The reported spot (from ${_currentSpot?.spotSourceName ?? "external source"})')
                                : const Text('The reported spot'),
                        value: widget.report.spotId,
                        enabled: !_isApplying &&
                            !(_currentSpot?.duplicateOf != null &&
                                _currentSpot!.duplicateOf!.isNotEmpty) &&
                            !(_currentSpot?.spotSource != null &&
                                _currentSpot!.spotSource!.isNotEmpty),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: Text(
                            'Original spot: ${_originalSpot!.name}'),
                        subtitle: _originalSpot!.spotSource != null &&
                                _originalSpot!.spotSource!.isNotEmpty
                            ? Text(
                                'The original spot (from ${_originalSpot!.spotSourceName ?? "external source"})')
                            : const Text(
                                'The original spot (recommended)'),
                        value: _originalSpot!.id!,
                        enabled: !_isApplying &&
                            !(_originalSpot!.spotSource != null &&
                                _originalSpot!.spotSource!.isNotEmpty),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (report.suggestedName != null)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Title',
                  fieldKey: 'name',
                  currentWidget: Text(
                    spot.name,
                    style: theme.textTheme.bodyMedium,
                  ),
                  suggestedWidget: Text(
                    report.suggestedName!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (report.suggestedDescription != null)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Description',
                  fieldKey: 'description',
                  currentWidget: Text(
                    spot.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  suggestedWidget: Text(
                    report.suggestedDescription!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (report.suggestedLatitude != null &&
                  report.suggestedLongitude != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Location',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Accept')),
                              ButtonSegment(
                                  value: false, label: Text('Reject')),
                            ],
                            selected: {_accepted['location'] ?? true},
                            onSelectionChanged: (s) {
                              setState(
                                  () => _accepted['location'] = s.first);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review the suggested location on the map below.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 280,
                          child: Stack(
                            children: [
                              _buildLocationReviewMap(
                                context,
                                current: LatLng(spot.latitude, spot.longitude),
                                suggested: LatLng(
                                  report.suggestedLatitude!,
                                  report.suggestedLongitude!,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: FloatingActionButton(
                                  onPressed: () {
                                    setState(() =>
                                        _isSatelliteView = !_isSatelliteView);
                                  },
                                  heroTag: 'mapTypeToggle',
                                  mini: true,
                                  tooltip: _isSatelliteView
                                      ? 'Switch to Map'
                                      : 'Switch to Hybrid',
                                  child: Icon(
                                    _isSatelliteView
                                        ? Icons.map
                                        : Icons.terrain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suggested',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.suggestedLatitude!.toStringAsFixed(4)}, ${report.suggestedLongitude!.toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (report.suggestedGoodFor != null &&
                  report.suggestedGoodFor!.isNotEmpty)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Good for',
                  fieldKey: 'goodFor',
                  currentWidget: _buildChipList(
                    context,
                    (spot.goodFor ?? [])
                        .map((k) => SpotAttributes.getLabel('goodFor', k))
                        .toList(),
                  ),
                  suggestedWidget: _buildChipList(
                    context,
                    report.suggestedGoodFor!
                        .map((k) => SpotAttributes.getLabel('goodFor', k))
                        .toList(),
                    isSuggested: true,
                  ),
                ),
              if (report.suggestedSpotFeatures != null &&
                  report.suggestedSpotFeatures!.isNotEmpty)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Features',
                  fieldKey: 'spotFeatures',
                  currentWidget: _buildChipList(
                    context,
                    (spot.spotFeatures ?? [])
                        .map((k) => SpotAttributes.getLabel('features', k))
                        .toList(),
                  ),
                  suggestedWidget: _buildChipList(
                    context,
                    report.suggestedSpotFeatures!
                        .map((k) => SpotAttributes.getLabel('features', k))
                        .toList(),
                    isSuggested: true,
                  ),
                ),
              if (report.suggestedSpotAccess != null)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Access',
                  fieldKey: 'spotAccess',
                  currentWidget: Text(
                    spot.spotAccess != null
                        ? SpotAttributes.getLabel('access', spot.spotAccess!)
                        : '—',
                    style: theme.textTheme.bodySmall,
                  ),
                  suggestedWidget: Text(
                    SpotAttributes.getLabel('access', report.suggestedSpotAccess!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (report.suggestedSpotFacilities != null &&
                  report.suggestedSpotFacilities!.isNotEmpty)
                _buildFieldRow(
                  context,
                  fieldLabel: 'Facilities',
                  fieldKey: 'spotFacilities',
                  currentWidget: _buildFacilitiesText(
                    context,
                    spot.spotFacilities ?? {},
                  ),
                  suggestedWidget: _buildFacilitiesText(
                    context,
                    report.suggestedSpotFacilities!,
                    isSuggested: true,
                  ),
                ),
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
                  hintText:
                      'Document why you accepted or rejected these suggestions...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
                enabled: !_isApplying,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isApplying ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (_isApplying || !_canSubmit()) ? null : _apply,
          child: _isApplying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isRejectAll() ? 'Submit Review' : 'Apply Selected'),
        ),
      ],
    );
  }

  Widget _buildLocationReviewMap(
    BuildContext context, {
    required LatLng current,
    required LatLng suggested,
  }) {
    final midLat = (current.latitude + suggested.latitude) / 2;
    final midLng = (current.longitude + suggested.longitude) / 2;
    final latSpan = (current.latitude - suggested.latitude).abs();
    final lngSpan = (current.longitude - suggested.longitude).abs();
    final span = (latSpan > lngSpan ? latSpan : lngSpan) * 111000;
    int zoom = 16;
    if (span > 500) zoom = 14;
    if (span > 2000) zoom = 12;
    if (span > 5000) zoom = 11;
    if (span > 10000) zoom = 10;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(midLat, midLng),
        zoom: zoom.toDouble(),
      ),
      mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
      markers: {
        Marker(
          markerId: const MarkerId('current'),
          position: current,
          infoWindow: const InfoWindow(title: 'Current', snippet: 'Existing location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('suggested'),
          position: suggested,
          infoWindow: const InfoWindow(title: 'Suggested', snippet: 'Proposed location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      webCameraControlEnabled: false,
      liteModeEnabled: kIsWeb,
      compassEnabled: false,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: true,
    );
  }

  Widget _buildChipList(
    BuildContext context,
    List<String> labels, {
    bool isSuggested = false,
  }) {
    final theme = Theme.of(context);
    if (labels.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: labels.map((l) {
        return Chip(
          label: Text(l, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isSuggested
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest,
        );
      }).toList(),
    );
  }

  Widget _buildFacilitiesText(
    BuildContext context,
    Map<String, String> facilities, {
    bool isSuggested = false,
  }) {
    final theme = Theme.of(context);
    if (facilities.isEmpty) {
      return Text('—', style: theme.textTheme.bodySmall);
    }
    final entries = facilities.entries.map((e) {
      final label = SpotAttributes.getLabel('facilities', e.key);
      final value = e.value;
      return '$label: $value';
    }).join(', ');
    return Text(
      entries,
      style: theme.textTheme.bodySmall?.copyWith(
        color: isSuggested ? theme.colorScheme.primary : null,
      ),
    );
  }
}
