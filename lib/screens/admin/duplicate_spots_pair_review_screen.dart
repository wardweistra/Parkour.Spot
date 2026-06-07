import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/spot_attributes.dart';
import '../../models/spot.dart';
import '../../services/auth_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/spot_service.dart';
import '../../services/url_service.dart';
import '../../utils/duplicate_spot_resolution_utils.dart';
import '../../utils/marker_icon_utils.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/resized_spot_image.dart';

class DuplicateSpotsPairReviewScreen extends StatefulWidget {
  const DuplicateSpotsPairReviewScreen({
    super.key,
    required this.runId,
    required this.pairIndex,
  });

  final String runId;
  final int pairIndex;

  @override
  State<DuplicateSpotsPairReviewScreen> createState() =>
      _DuplicateSpotsPairReviewScreenState();
}

class _DuplicateSpotsPairReviewScreenState
    extends State<DuplicateSpotsPairReviewScreen> {
  static const int _duplicateRangeMeters = 50;

  late Future<_DuplicateClusterReviewData> _reviewFuture;
  final TextEditingController _notesController = TextEditingController();
  String? _selectedReportId;
  String? _initializedForClusterKey;
  String? _baseSpotId;
  String? _titleSpotId;
  String? _descriptionSpotId;
  String? _locationSpotId;
  String? _attributesSpotId;
  final Set<String> _photoSpotIds = {};
  final Set<String> _youtubeSpotIds = {};
  bool _isResolving = false;
  String? _resolvedNativeSpotId;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _loadReviewData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<_DuplicateClusterReviewData> _loadReviewData() async {
    final spotService = context.read<SpotService>();
    final runDoc = await FirebaseFirestore.instance
        .collection('duplicateDetectionResults')
        .doc(widget.runId)
        .get();
    if (!runDoc.exists) {
      throw StateError('Duplicate detection run not found');
    }

    final data = runDoc.data() ?? <String, dynamic>{};
    final rawPairs = data['pairs'] as List<dynamic>? ?? <dynamic>[];
    final pairRefs = rawPairs
        .whereType<Map<String, dynamic>>()
        .map(DuplicateSpotPairRef.fromMap)
        .whereType<DuplicateSpotPairRef>()
        .toList();
    if (widget.pairIndex < 0 || widget.pairIndex >= pairRefs.length) {
      throw StateError('Duplicate pair not found');
    }

    final connectedIds = buildConnectedDuplicateSpotIds(
      pairs: pairRefs,
      startIndex: widget.pairIndex,
      maxDistanceMeters: _duplicateRangeMeters,
    );
    final spots = await spotService.findDuplicateClusterFromSeeds(
      connectedIds,
      maxDistanceMeters: _duplicateRangeMeters,
    );
    if (spots.length < 2) {
      throw StateError('Could not load at least two spots for this cluster');
    }

    final clusterIds = spots.map((spot) => spot.id).whereType<String>().toSet();
    final pairIndices = findPairIndicesWithinCluster(
      pairs: pairRefs,
      clusterSpotIds: clusterIds,
      maxDistanceMeters: _duplicateRangeMeters,
    );
    if (!pairIndices.contains(widget.pairIndex)) {
      pairIndices.add(widget.pairIndex);
      pairIndices.sort();
    }

    return _DuplicateClusterReviewData(
      runId: widget.runId,
      pairIndex: widget.pairIndex,
      sourceName: data['sourceName'] as String? ?? 'Unknown source',
      spots: spots,
      pairRefs: pairRefs,
      resolvedPairIndices: pairIndices,
      existingResolution:
          (data['pairResolutions']
                  as Map<String, dynamic>?)?['${widget.pairIndex}']
              as Map<String, dynamic>?,
    );
  }

  void _ensureSelectionDefaults(_DuplicateClusterReviewData data) {
    final clusterKey = data.spots.map((spot) => spot.id).join('|');
    if (_initializedForClusterKey == clusterKey) return;

    final clickedPair = data.pairRefs[data.pairIndex];
    final clickedSpots = data.spots.where((spot) {
      return spot.id == clickedPair.spot1Id || spot.id == clickedPair.spot2Id;
    }).toList();
    final baseSpot =
        clickedSpots.where((spot) => spot.spotSource == null).firstOrNull ??
        data.spots.where((spot) => spot.spotSource == null).firstOrNull ??
        clickedSpots.firstOrNull ??
        data.spots.first;
    final baseId = baseSpot.id!;

    _initializedForClusterKey = clusterKey;
    _baseSpotId = baseId;
    _titleSpotId = baseId;
    _descriptionSpotId = baseId;
    _locationSpotId = baseId;
    _attributesSpotId = baseId;
    _photoSpotIds
      ..clear()
      ..addAll(
        data.spots
            .where((spot) => spot.imageUrls?.isNotEmpty ?? false)
            .map((spot) => spot.id)
            .whereType<String>(),
      );
    _youtubeSpotIds
      ..clear()
      ..addAll(
        data.spots
            .where((spot) => spot.youtubeVideoIds?.isNotEmpty ?? false)
            .map((spot) => spot.id)
            .whereType<String>(),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return _buildScaffold(
        body: const Center(child: Text('Moderator access required')),
      );
    }

    return _buildScaffold(
      body: FutureBuilder<_DuplicateClusterReviewData>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          _ensureSelectionDefaults(data);
          final preview = _buildPreview(data.spots);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildIntro(data),
              const SizedBox(height: 12),
              _buildClusterMap(data.spots),
              const SizedBox(height: 12),
              _buildSpotDetailsGrid(data.spots),
              const SizedBox(height: 12),
              _buildSelectionPanel(data.spots),
              const SizedBox(height: 12),
              _buildPreviewPanel(preview),
              const SizedBox(height: 12),
              _buildConfirmPanel(data, preview),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return PageScaffold(
      title: 'Resolve Duplicate Cluster',
      scrollable: false,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/moderator/duplicate-spots/${widget.runId}');
        }
      },
      body: body,
    );
  }

  Spot _buildPreview(List<Spot> spots) {
    return buildDuplicateNativeSpotPreview(
      spots: spots,
      baseSpotId: _baseSpotId!,
      titleSpotId: _titleSpotId!,
      descriptionSpotId: _descriptionSpotId!,
      locationSpotId: _locationSpotId!,
      attributesSpotId: _attributesSpotId!,
      photoSpotIds: _photoSpotIds,
      youtubeSpotIds: _youtubeSpotIds,
    );
  }

  Widget _buildIntro(_DuplicateClusterReviewData data) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolution = data.existingResolution;
    final nativeSpotId = resolution?['nativeSpotId'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.merge_type, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cluster from ${data.sourceName} pair #${data.pairIndex + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.spots.length} spots are connected within $_duplicateRangeMeters meters. Resolving this cluster will mark ${data.resolvedPairIndices.length} detection pair${data.resolvedPairIndices.length == 1 ? '' : 's'} as resolved.',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
                if (nativeSpotId != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/spot/$nativeSpotId'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open existing native resolution'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterMap(List<Spot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cluster map', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _DuplicateClusterMap(
              spots: spots,
              selectedLocationSpotId: _locationSpotId,
              height: 320,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotDetailsGrid(List<Spot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spot details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: spots
                      .map(
                        (spot) => SizedBox(
                          width: cardWidth,
                          child: _buildSpotCard(spot),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotCard(Spot spot) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(spot),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name.isEmpty ? 'Unnamed spot' : spot.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sourceLabel(spot),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (spot.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                spot.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            _detailLine(Icons.place, _locationLabel(spot)),
            _detailLine(
              Icons.gps_fixed,
              '${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}',
            ),
            _detailLine(
              Icons.photo_library,
              '${spot.imageUrls?.length ?? 0} photos · ${spot.youtubeVideoIds?.length ?? 0} videos',
            ),
            _buildAttributeSummary(spot),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _openSpotDetails(spot),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Details'),
                ),
                TextButton.icon(
                  onPressed: () => context.push(
                    '/explore?locateSpotId=${Uri.encodeComponent(spot.id!)}',
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Locate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Spot spot) {
    final imageUrl = spot.imageUrls?.firstOrNull;
    if (imageUrl == null) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ResizedSpotImage(
        imageUrl: imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _detailLine(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeSummary(Spot spot) {
    final chips = <Widget>[];
    if (spot.spotAccess != null) {
      chips.add(
        _smallChip(SpotAttributes.getLabel('access', spot.spotAccess!)),
      );
    }
    chips.addAll(
      (spot.spotFeatures ?? <String>[]).map(
        (key) => _smallChip(SpotAttributes.getLabel('features', key)),
      ),
    );
    chips.addAll(
      (spot.goodFor ?? <String>[]).map(
        (key) => _smallChip(SpotAttributes.getLabel('goodFor', key)),
      ),
    );
    spot.spotFacilities?.forEach((key, value) {
      if (value == 'true') {
        chips.add(_smallChip(SpotAttributes.getLabel('facilities', key)));
      }
    });

    if (chips.isEmpty) {
      return _detailLine(Icons.tune, 'No attributes');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips.take(8).toList()),
    );
  }

  Widget _smallChip(String label) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildSelectionPanel(List<Spot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create native spot from cluster',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _spotDropdown(
              label: 'Basis for the native spot',
              value: _baseSpotId,
              spots: spots,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _baseSpotId = value;
                  _titleSpotId = value;
                  _descriptionSpotId = value;
                  _locationSpotId = value;
                  _attributesSpotId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 760;
                final width = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _spotDropdown(
                        label: 'Title from',
                        value: _titleSpotId,
                        spots: spots,
                        onChanged: (value) =>
                            setState(() => _titleSpotId = value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _spotDropdown(
                        label: 'Description from',
                        value: _descriptionSpotId,
                        spots: spots,
                        onChanged: (value) =>
                            setState(() => _descriptionSpotId = value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _spotDropdown(
                        label: 'Location from',
                        value: _locationSpotId,
                        spots: spots,
                        onChanged: (value) =>
                            setState(() => _locationSpotId = value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _spotDropdown(
                        label: 'Attributes from',
                        value: _attributesSpotId,
                        spots: spots,
                        onChanged: (value) =>
                            setState(() => _attributesSpotId = value),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Photos to include',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            _checkboxWrap(
              spots: spots.where((spot) => spot.imageUrls?.isNotEmpty ?? false),
              selectedIds: _photoSpotIds,
              emptyText: 'No spots in this cluster have photos.',
            ),
            const SizedBox(height: 12),
            Text(
              'Videos to include',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            _checkboxWrap(
              spots: spots.where(
                (spot) => spot.youtubeVideoIds?.isNotEmpty ?? false,
              ),
              selectedIds: _youtubeSpotIds,
              emptyText: 'No spots in this cluster have videos.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _spotDropdown({
    required String label,
    required String? value,
    required List<Spot> spots,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: spots.map((spot) {
        return DropdownMenuItem(
          value: spot.id,
          child: Text(
            '${spot.name.isEmpty ? 'Unnamed spot' : spot.name} · ${_sourceLabel(spot)}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _checkboxWrap({
    required Iterable<Spot> spots,
    required Set<String> selectedIds,
    required String emptyText,
  }) {
    final items = spots.toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(emptyText),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((spot) {
        final spotId = spot.id!;
        final count =
            spot.imageUrls?.length ?? spot.youtubeVideoIds?.length ?? 0;
        return FilterChip(
          label: Text('${spot.name} ($count)'),
          selected: selectedIds.contains(spotId),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedIds.add(spotId);
              } else {
                selectedIds.remove(spotId);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPreviewPanel(Spot preview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(preview.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              preview.description.isEmpty
                  ? 'No description'
                  : preview.description,
            ),
            const SizedBox(height: 8),
            _detailLine(Icons.place, _locationLabel(preview)),
            _detailLine(
              Icons.gps_fixed,
              '${preview.latitude.toStringAsFixed(6)}, ${preview.longitude.toStringAsFixed(6)}',
            ),
            _detailLine(
              Icons.photo_library,
              '${preview.imageUrls?.length ?? 0} photos · ${preview.youtubeVideoIds?.length ?? 0} videos',
            ),
            _buildAttributeSummary(preview),
            if (preview.imageUrls?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: preview.imageUrls!.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ResizedSpotImage(
                        imageUrl: preview.imageUrls![index],
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmPanel(_DuplicateClusterReviewData data, Spot preview) {
    final authService = context.watch<AuthService>();
    final canResolve = !_isResolving && _resolvedNativeSpotId == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm resolution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ModeratorActionFields(
              spotId: _baseSpotId,
              notesController: _notesController,
              onReportSelected: (reportId) {
                _selectedReportId = reportId;
              },
              showReportSelector: true,
            ),
            const SizedBox(height: 16),
            if (_resolvedNativeSpotId != null)
              FilledButton.icon(
                onPressed: () => context.push('/spot/$_resolvedNativeSpotId'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open created native spot'),
              )
            else
              FilledButton.icon(
                onPressed: canResolve
                    ? () => _confirmResolution(data, preview, authService)
                    : null,
                icon: _isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isResolving
                      ? 'Resolving cluster...'
                      : 'Create native spot and resolve cluster',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResolution(
    _DuplicateClusterReviewData data,
    Spot preview,
    AuthService authService,
  ) async {
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      _showSnack('You must be signed in to resolve duplicate clusters.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve duplicate cluster?'),
        content: Text(
          'This will create one native spot named "${preview.name}" and mark ${data.spots.length} cluster spots as duplicates of it. ${data.resolvedPairIndices.length} duplicate detection pair${data.resolvedPairIndices.length == 1 ? '' : 's'} will be marked resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResolving = true);
    final spotService = context.read<SpotService>();
    final userName =
        authService.userProfile?.displayName ??
        currentUser.displayName ??
        currentUser.email ??
        currentUser.uid;
    final nativeSpotId = await spotService.resolveDuplicateClusterToNative(
      clusterSpots: data.spots,
      previewSpot: preview,
      userId: currentUser.uid,
      userName: userName,
      runId: data.runId,
      resolvedPairIndices: data.resolvedPairIndices,
      reportId: _selectedReportId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isResolving = false;
      _resolvedNativeSpotId = nativeSpotId;
    });
    if (nativeSpotId == null) {
      _showSnack(spotService.error ?? 'Failed to resolve duplicate cluster.');
      return;
    }
    _showSnack('Duplicate cluster resolved.');
  }

  Future<void> _openSpotDetails(Spot spot) async {
    final spotId = spot.id!;
    if (MobileDetectionService.isRunningInBrowser) {
      final uri = Uri.parse(
        UrlService.generateSpotUrl(
          spotId,
          countryCode: spot.countryCode,
          city: spot.city,
        ),
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (mounted) {
      context.push(
        UrlService.generateNavigationUrl(
          spotId,
          countryCode: spot.countryCode,
          city: spot.city,
        ),
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sourceLabel(Spot spot) {
    return spot.spotSourceName ?? spot.spotSource ?? 'Native parkour.spot';
  }

  String _locationLabel(Spot spot) {
    final parts = [
      spot.address,
      spot.city,
      spot.countryCode,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'No address' : parts.join(', ');
  }
}

class _DuplicateClusterReviewData {
  const _DuplicateClusterReviewData({
    required this.runId,
    required this.pairIndex,
    required this.sourceName,
    required this.spots,
    required this.pairRefs,
    required this.resolvedPairIndices,
    this.existingResolution,
  });

  final String runId;
  final int pairIndex;
  final String sourceName;
  final List<Spot> spots;
  final List<DuplicateSpotPairRef> pairRefs;
  final List<int> resolvedPairIndices;
  final Map<String, dynamic>? existingResolution;
}

class _DuplicateClusterMap extends StatefulWidget {
  const _DuplicateClusterMap({
    required this.spots,
    required this.selectedLocationSpotId,
    required this.height,
  });

  final List<Spot> spots;
  final String? selectedLocationSpotId;
  final double height;

  @override
  State<_DuplicateClusterMap> createState() => _DuplicateClusterMapState();
}

class _DuplicateClusterMapState extends State<_DuplicateClusterMap> {
  bool _isSatelliteView = false;
  BitmapDescriptor? _normalPinIcon;
  BitmapDescriptor? _selectedPinIcon;

  @override
  void initState() {
    super.initState();
    _loadPinIcons();
  }

  Future<void> _loadPinIcons() async {
    final double h = MarkerIconUtils.mapPinSingleSpotLogicalHeight;
    final normal = await MarkerIconUtils.loadMapPinPng(
      MarkerIconUtils.mapPinNormalAsset,
      fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
      logicalHeight: h,
    );
    final selected = await MarkerIconUtils.loadMapPinPng(
      MarkerIconUtils.mapPinNormalSelectedAsset,
      fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
      logicalHeight: h,
    );
    if (!mounted) return;
    setState(() {
      _normalPinIcon = normal;
      _selectedPinIcon = selected;
    });
  }

  LatLng get _cameraTarget {
    final latSum = widget.spots.fold<double>(
      0,
      (total, spot) => total + spot.latitude,
    );
    final lngSum = widget.spots.fold<double>(
      0,
      (total, spot) => total + spot.longitude,
    );
    return LatLng(latSum / widget.spots.length, lngSum / widget.spots.length);
  }

  double get _cameraZoom {
    if (widget.spots.length <= 1) return 16;
    final latitudes = widget.spots.map((spot) => spot.latitude);
    final longitudes = widget.spots.map((spot) => spot.longitude);
    final latSpan =
        (latitudes.reduce((a, b) => a > b ? a : b) -
                latitudes.reduce((a, b) => a < b ? a : b))
            .abs();
    final lngSpan =
        (longitudes.reduce((a, b) => a > b ? a : b) -
                longitudes.reduce((a, b) => a < b ? a : b))
            .abs();
    final span = (latSpan > lngSpan ? latSpan : lngSpan) * 111000;
    if (span > 10000) return 10;
    if (span > 5000) return 11;
    if (span > 2000) return 12;
    if (span > 500) return 14;
    return 16;
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    for (var i = 0; i < widget.spots.length; i++) {
      final spot = widget.spots[i];
      final selected = spot.id == widget.selectedLocationSpotId;
      markers.add(
        Marker(
          markerId: MarkerId(spot.id ?? 'spot-$i'),
          position: LatLng(spot.latitude, spot.longitude),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet:
                spot.spotSourceName ?? spot.spotSource ?? 'Native parkour.spot',
          ),
          icon: selected
              ? (_selectedPinIcon ?? BitmapDescriptor.defaultMarker)
              : (_normalPinIcon ?? BitmapDescriptor.defaultMarker),
          anchor: const Offset(0.5, 1.0),
          zIndexInt: selected ? 10 + i : i,
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              key: ValueKey(
                'duplicate_cluster_${widget.spots.map((spot) => spot.id).join('_')}_${widget.selectedLocationSpotId ?? ''}',
              ),
              initialCameraPosition: CameraPosition(
                target: _cameraTarget,
                zoom: _cameraZoom,
              ),
              mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
              markers: _markers(),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              webCameraControlEnabled: false,
              liteModeEnabled: kIsWeb,
              compassEnabled: false,
              tiltGesturesEnabled: false,
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: FloatingActionButton(
                heroTag: 'duplicateClusterMapType_${widget.spots.length}',
                mini: true,
                tooltip: _isSatelliteView
                    ? 'Switch to Map'
                    : 'Switch to Hybrid',
                onPressed: () {
                  setState(() => _isSatelliteView = !_isSatelliteView);
                },
                child: Icon(_isSatelliteView ? Icons.map : Icons.terrain),
              ),
            ),
            if (widget.spots.length > 1)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${widget.spots.length} cluster pins · highlighted pin supplies preview location',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
