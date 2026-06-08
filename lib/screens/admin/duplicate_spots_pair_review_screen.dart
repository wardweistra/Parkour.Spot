import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../widgets/custom_text_field.dart';
import '../../widgets/detail_network_gallery_viewer.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/resized_spot_image.dart';
import '../../widgets/spot_form/attributes_section.dart';
import '../../widgets/spot_form/image_section.dart';

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

  _DuplicateClusterReviewData? _loadedData;
  Object? _loadError;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _previewNameController = TextEditingController();
  final TextEditingController _previewDescriptionController =
      TextEditingController();
  final List<String> _previewImageUrls = [];
  String? _previewAccess;
  final Set<String> _previewFeatures = {};
  final Map<String, String> _previewFacilities = {};
  final Set<String> _previewGoodFor = {};
  String? _selectedReportId;
  String? _initializedForClusterKey;
  String? _baseSpotId;
  String? _titleSpotId;
  String? _descriptionSpotId;
  String? _locationSpotId;
  String? _accessSpotId;
  String? _facilitiesSpotId;
  final Set<String> _featureSpotIds = {};
  final Set<String> _goodForSpotIds = {};
  final Set<String> _includedSpotIds = {};
  final Set<String> _photoSpotIds = {};
  final Set<String> _youtubeSpotIds = {};
  bool _isResolving = false;
  String? _resolvedNativeSpotId;
  bool _isEditingPreview = false;
  bool _previewEditsActive = false;

  @override
  void initState() {
    super.initState();
    _loadReviewData().then((data) {
      if (!mounted) return;
      setState(() {
        _ensureSelectionDefaults(data);
        _loadedData = data;
      });
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _previewNameController.dispose();
    _previewDescriptionController.dispose();
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

    final data = firestoreMap(runDoc.data());
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
      spots: sortSpotsByOptionalDetailRichness(spots),
      pairRefs: pairRefs,
      resolvedPairIndices: pairIndices,
      existingResolution: firestoreMapOrNull(
        firestoreMap(data['pairResolutions'])['${widget.pairIndex}'],
      ),
    );
  }

  void _ensureSelectionDefaults(_DuplicateClusterReviewData data) {
    final clusterKey = (data.spots.map((spot) => spot.id).whereType<String>().toList()
          ..sort())
        .join('|');
    if (_initializedForClusterKey == clusterKey) return;

    final defaults = buildDuplicateClusterMergeDefaults(data.spots);

    _initializedForClusterKey = clusterKey;
    _includedSpotIds
      ..clear()
      ..addAll(
        data.spots
            .where((spot) => !isSpotAlreadyMarkedAsDuplicate(spot))
            .map((spot) => spot.id)
            .whereType<String>(),
      );
    _baseSpotId = defaults.basisSpotId;
    _titleSpotId = defaults.titleSpotId;
    _descriptionSpotId = defaults.descriptionSpotId;
    _locationSpotId = defaults.locationSpotId;
    _accessSpotId = defaults.accessSpotId;
    _facilitiesSpotId = defaults.facilitiesSpotId;
    _featureSpotIds
      ..clear()
      ..addAll(defaults.featureSpotIds);
    _goodForSpotIds
      ..clear()
      ..addAll(defaults.goodForSpotIds);
    _photoSpotIds
      ..clear()
      ..addAll(defaults.photoSpotIds);
    _youtubeSpotIds
      ..clear()
      ..addAll(defaults.youtubeSpotIds);
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
      body: Builder(
        builder: (context) {
          if (_loadError != null) {
            return Center(child: Text('Error: $_loadError'));
          }
          if (_loadedData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = _loadedData!;
          final includedSpots = _includedSpots(data.spots);
          final preview = _buildPreview(includedSpots);
          final mergePairCount = _resolvedPairIndicesForMerge(data).length;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildIntro(data),
              const SizedBox(height: 12),
              _buildClusterMap(data.spots),
              const SizedBox(height: 12),
              _buildSpotDetailsTable(data.spots),
              const SizedBox(height: 12),
              _buildPreviewPanel(preview, data.spots),
              const SizedBox(height: 12),
              _buildConfirmPanel(data, mergePairCount: mergePairCount),
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

  List<Spot> _includedSpots(List<Spot> spots) {
    return spots
        .where((spot) => _includedSpotIds.contains(spot.id))
        .toList(growable: false);
  }

  List<int> _resolvedPairIndicesForMerge(_DuplicateClusterReviewData data) {
    return data.resolvedPairIndices.where((index) {
      final pair = data.pairRefs[index];
      return _includedSpotIds.contains(pair.spot1Id) &&
          _includedSpotIds.contains(pair.spot2Id);
    }).toList(growable: false);
  }

  void _reconcileSelections(List<Spot> spots) {
    final included = _includedSpots(spots);
    if (included.isEmpty) return;

    final fallbackId = included.first.id!;
    if (!_includedSpotIds.contains(_baseSpotId)) {
      _baseSpotId = fallbackId;
    }
    if (!_includedSpotIds.contains(_titleSpotId)) {
      _titleSpotId = fallbackId;
    }
    if (!_includedSpotIds.contains(_descriptionSpotId)) {
      _descriptionSpotId = fallbackId;
    }
    if (!_includedSpotIds.contains(_locationSpotId)) {
      _locationSpotId = fallbackId;
    }
    if (!_includedSpotIds.contains(_accessSpotId)) {
      _accessSpotId = fallbackId;
    }
    if (!_includedSpotIds.contains(_facilitiesSpotId)) {
      _facilitiesSpotId = fallbackId;
    }

    _featureSpotIds.removeWhere((spotId) => !_includedSpotIds.contains(spotId));
    _goodForSpotIds.removeWhere((spotId) => !_includedSpotIds.contains(spotId));
    _photoSpotIds.removeWhere((spotId) => !_includedSpotIds.contains(spotId));
    _youtubeSpotIds.removeWhere((spotId) => !_includedSpotIds.contains(spotId));
  }

  void _setSpotIncluded(String spotId, bool included, List<Spot> spots) {
    if (!included && _includedSpotIds.length <= 2) return;
    if (included &&
        spots.any(
          (spot) => spot.id == spotId && isSpotAlreadyMarkedAsDuplicate(spot),
        )) {
      return;
    }

    setState(() {
      if (included) {
        _includedSpotIds.add(spotId);
      } else {
        _includedSpotIds.remove(spotId);
        _photoSpotIds.remove(spotId);
        _youtubeSpotIds.remove(spotId);
        _featureSpotIds.remove(spotId);
        _goodForSpotIds.remove(spotId);
      }
      _reconcileSelections(spots);
      _afterMergeSelectionChanged(spots);
    });
  }

  void _afterMergeSelectionChanged(List<Spot> spots) {
    if (_isEditingPreview) {
      _refreshPreviewEdits(spots);
    } else {
      _previewEditsActive = false;
    }
  }

  void _enterPreviewEditMode(List<Spot> spots) {
    setState(() {
      _refreshPreviewEdits(spots);
      _previewEditsActive = true;
      _isEditingPreview = true;
    });
  }

  void _exitPreviewEditMode() {
    setState(() {
      _previewEditsActive = true;
      _isEditingPreview = false;
    });
  }

  void _refreshPreviewEdits(List<Spot> spots) {
    final includedSpots = _includedSpots(spots);
    if (includedSpots.isEmpty) return;

    final computed = buildDuplicateNativeSpotPreview(
      spots: includedSpots,
      baseSpotId: _baseSpotId!,
      titleSpotId: _titleSpotId!,
      descriptionSpotId: _descriptionSpotId!,
      locationSpotId: _locationSpotId!,
      accessSpotId: _accessSpotId!,
      facilitiesSpotId: _facilitiesSpotId!,
      featureSpotIds: _featureSpotIds,
      goodForSpotIds: _goodForSpotIds,
      photoSpotIds: _photoSpotIds,
      youtubeSpotIds: _youtubeSpotIds,
    );

    _previewNameController.text = computed.name;
    _previewDescriptionController.text = computed.description;
    _previewImageUrls
      ..clear()
      ..addAll(computed.imageUrls ?? const <String>[]);
    _previewAccess = computed.spotAccess;
    _previewFeatures
      ..clear()
      ..addAll(computed.spotFeatures ?? const <String>[]);
    _previewFacilities
      ..clear()
      ..addAll(_facilitiesForAttributesEditor(computed.spotFacilities));
    _previewGoodFor
      ..clear()
      ..addAll(computed.goodFor ?? const <String>[]);
  }

  Map<String, String> _facilitiesForAttributesEditor(
    Map<String, String>? raw,
  ) {
    if (raw == null || raw.isEmpty) return {};
    return Map.fromEntries(
      raw.entries.map((entry) {
        final value = entry.value;
        if (value == 'true') {
          return MapEntry(entry.key, 'yes');
        }
        if (value == 'false') {
          return MapEntry(entry.key, 'no');
        }
        return MapEntry(entry.key, value);
      }),
    );
  }

  Spot _buildPreview(List<Spot> includedSpots) {
    final computed = buildDuplicateNativeSpotPreview(
      spots: includedSpots,
      baseSpotId: _baseSpotId!,
      titleSpotId: _titleSpotId!,
      descriptionSpotId: _descriptionSpotId!,
      locationSpotId: _locationSpotId!,
      accessSpotId: _accessSpotId!,
      facilitiesSpotId: _facilitiesSpotId!,
      featureSpotIds: _featureSpotIds,
      goodForSpotIds: _goodForSpotIds,
      photoSpotIds: _photoSpotIds,
      youtubeSpotIds: _youtubeSpotIds,
    );

    if (!_previewEditsActive) {
      return computed;
    }

    final trimmedName = _previewNameController.text.trim();
    final trimmedDescription = _previewDescriptionController.text.trim();

    return computed.copyWith(
      name: trimmedName.isNotEmpty ? trimmedName : computed.name,
      description: trimmedDescription,
      imageUrls: _previewImageUrls.isEmpty
          ? null
          : List<String>.from(_previewImageUrls),
      spotAccess: _previewAccess,
      spotFeatures: _previewFeatures.isEmpty
          ? null
          : _previewFeatures.toList(growable: false),
      spotFacilities: _previewFacilities.isEmpty
          ? null
          : Map<String, String>.from(_previewFacilities),
      goodFor: _previewGoodFor.isEmpty
          ? null
          : _previewGoodFor.toList(growable: false),
    );
  }

  void _removePreviewImageAt(int index) {
    setState(() => _previewImageUrls.removeAt(index));
  }

  void _reorderPreviewImage(int oldIndex, int newIndex) {
    setState(() {
      final imageUrl = _previewImageUrls.removeAt(oldIndex);
      _previewImageUrls.insert(newIndex, imageUrl);
    });
  }

  void _onPreviewAccessChanged(String? value) {
    setState(() => _previewAccess = value);
  }

  void _togglePreviewFeature(String key, bool selected) {
    setState(() {
      if (selected) {
        _previewFeatures.add(key);
      } else {
        _previewFeatures.remove(key);
      }
    });
  }

  void _onPreviewFacilityChanged(String key, String value) {
    setState(() => _previewFacilities[key] = value);
  }

  void _togglePreviewGoodFor(String key, bool selected) {
    setState(() {
      if (selected) {
        _previewGoodFor.add(key);
      } else {
        _previewGoodFor.remove(key);
      }
    });
  }

  Widget _buildIntro(_DuplicateClusterReviewData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final resolution = data.existingResolution;
    final nativeSpotId = resolution?['nativeSpotId'] as String?;
    final spotCount = data.spots.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.merge_type, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cluster from ${data.sourceName} pair #${data.pairIndex + 1}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: _buildResolutionConfirmRow(
              icon: Icons.place_outlined,
              label: 'Spots found',
              value: '$spotCount spot${spotCount == 1 ? '' : 's'}',
              valueStyle: valueStyle,
            ),
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

  Widget _buildSpotDetailsTable(List<Spot> spots) {
    final colorScheme = Theme.of(context).colorScheme;
    const labelWidth = 132.0;
    const spotColumnWidth = 280.0;

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
            const SizedBox(height: 4),
            Text(
              'Uncheck spots to leave out of the merge. Pick sources per field; feature and good-for tags each combine across their checked spots.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildComparisonGridRow(
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      backgroundColor: colorScheme.surfaceContainerLow,
                      label: const SizedBox.shrink(),
                      spotCells: spots
                          .map(
                            (spot) => _wrapIncludedSpotColumn(
                              spot.id!,
                              colorScheme,
                              _buildSpotTableHeader(spot, colorScheme),
                            ),
                          )
                          .toList(),
                    ),
                    _buildIncludeGridRow(
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      spots: spots,
                    ),
                    _buildRadioGridRow(
                      label: 'Basis',
                      tooltip: 'Ranking and default fallback for empty fields',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _baseSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) {
                        setState(() {
                          _baseSpotId = spotId;
                          _titleSpotId = spotId;
                          _descriptionSpotId = spotId;
                          _locationSpotId = spotId;
                          _accessSpotId = spotId;
                          _facilitiesSpotId = spotId;
                          _afterMergeSelectionChanged(spots);
                        });
                      },
                    ),
                    _buildRadioGridRow(
                      label: 'Title',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _titleSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) => setState(() {
                        _titleSpotId = spotId;
                        _afterMergeSelectionChanged(spots);
                      }),
                      cellBuilder: (spot) => Text(
                        spot.name.isEmpty ? 'Unnamed spot' : spot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildRadioGridRow(
                      label: 'Description',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _descriptionSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) => setState(() {
                        _descriptionSpotId = spotId;
                        _afterMergeSelectionChanged(spots);
                      }),
                      cellBuilder: (spot) => Text(
                        spot.description.trim().isEmpty
                            ? 'No description'
                            : spot.description,
                      ),
                    ),
                    _buildRadioGridRow(
                      label: 'Location',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _locationSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) => setState(() {
                        _locationSpotId = spotId;
                        _afterMergeSelectionChanged(spots);
                      }),
                      cellBuilder: (spot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_locationLabel(spot)),
                          const SizedBox(height: 4),
                          Text(
                            '${spot.latitude.toStringAsFixed(6)}, '
                            '${spot.longitude.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _buildRadioGridRow(
                      label: 'Access',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _accessSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) => setState(() {
                        _accessSpotId = spotId;
                        _afterMergeSelectionChanged(spots);
                      }),
                      cellBuilder: (spot) => _buildAccessSummary(spot),
                    ),
                    _buildRadioGridRow(
                      label: 'Facilities',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      groupValue: _facilitiesSpotId,
                      spots: spots,
                      isSpotEnabled: _isSpotIncludedInMerge,
                      onChanged: (spotId) => setState(() {
                        _facilitiesSpotId = spotId;
                        _afterMergeSelectionChanged(spots);
                      }),
                      cellBuilder: (spot) => _buildFacilitiesSummary(spot),
                    ),
                    _buildAdditiveAttributeGridRow(
                      label: 'Features',
                      tooltip: 'Combine spot features from every checked spot',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      spots: spots,
                      selectedIds: _featureSpotIds,
                      countFor: (spot) => spot.spotFeatures?.length ?? 0,
                      emptyLabel: 'No features',
                      summaryBuilder: _buildFeaturesSummary,
                    ),
                    _buildAdditiveAttributeGridRow(
                      label: 'Good for',
                      tooltip: 'Combine good-for tags from every checked spot',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      spots: spots,
                      selectedIds: _goodForSpotIds,
                      countFor: (spot) => spot.goodFor?.length ?? 0,
                      emptyLabel: 'No good-for tags',
                      summaryBuilder: _buildGoodForSummary,
                    ),
                    _buildMediaGridRow(
                      label: 'Photos',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      spots: spots,
                      selectedIds: _photoSpotIds,
                      countFor: (spot) => spot.imageUrls?.length ?? 0,
                      hasMedia: (spot) => spot.imageUrls?.isNotEmpty ?? false,
                      previewBuilder: _buildSpotPhotoPreviews,
                    ),
                    _buildMediaGridRow(
                      label: 'Videos',
                      labelWidth: labelWidth,
                      spotColumnWidth: spotColumnWidth,
                      colorScheme: colorScheme,
                      spots: spots,
                      selectedIds: _youtubeSpotIds,
                      countFor: (spot) => spot.youtubeVideoIds?.length ?? 0,
                      hasMedia: (spot) =>
                          spot.youtubeVideoIds?.isNotEmpty ?? false,
                      isLastRow: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSpotIncludedInMerge(Spot spot) =>
      _includedSpotIds.contains(spot.id);

  Widget _wrapIncludedSpotColumn(
    String spotId,
    ColorScheme colorScheme,
    Widget child,
  ) {
    if (_includedSpotIds.contains(spotId)) return child;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Opacity(opacity: 0.72, child: child),
    );
  }

  Widget _buildIncludeGridRow({
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required List<Spot> spots,
  }) {
    return _buildComparisonGridRow(
      labelWidth: labelWidth,
      spotColumnWidth: spotColumnWidth,
      colorScheme: colorScheme,
      label: _buildTableLabelCell(
        'Include',
        tooltip: 'At least two spots must stay included',
      ),
      spotCells: spots.map((spot) {
        final spotId = spot.id!;
        final isAlreadyDuplicate = isSpotAlreadyMarkedAsDuplicate(spot);
        final isIncluded = _includedSpotIds.contains(spotId);
        final canExclude = _includedSpotIds.length > 2 || !isIncluded;
        final canToggle = !isAlreadyDuplicate && canExclude;
        return Padding(
          padding: const EdgeInsets.all(10),
          child: CheckboxListTile(
            value: isIncluded,
            onChanged: canToggle
                ? (checked) =>
                      _setSpotIncluded(spotId, checked ?? false, spots)
                : null,
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              isAlreadyDuplicate
                  ? 'Already duplicate'
                  : (isIncluded ? 'In merge' : 'Excluded'),
            ),
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpotTableHeader(Spot spot, ColorScheme colorScheme) {
    final spotId = spot.id!;
    final isBasis = spotId == _baseSpotId;
    final duplicateOf = spot.duplicateOf?.trim();
    final isAlreadyDuplicate =
        duplicateOf != null && duplicateOf.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(spot, size: 56),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name.isEmpty ? 'Unnamed spot' : spot.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sourceLabel(spot),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isBasis)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Basis',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    if (isAlreadyDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Duplicate of another spot',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              if (isAlreadyDuplicate)
                TextButton(
                  onPressed: () => context.push('/spot/$duplicateOf'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Open original'),
                ),
              TextButton(
                onPressed: () => _openSpotDetails(spot),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Details'),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/explore?locateSpotId=${Uri.encodeComponent(spotId)}',
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Locate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonGridRow({
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required Widget label,
    required List<Widget> spotCells,
    Color? backgroundColor,
    bool isLastRow = false,
  }) {
    return _buildComparisonGridRowShell(
      labelWidth: labelWidth,
      spotColumnWidth: spotColumnWidth,
      colorScheme: colorScheme,
      backgroundColor: backgroundColor,
      isLastRow: isLastRow,
      label: label,
      spotCells: spotCells,
    );
  }

  Widget _buildRadioGridRow({
    required String label,
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required String? groupValue,
    required List<Spot> spots,
    required ValueChanged<String> onChanged,
    bool Function(Spot spot)? isSpotEnabled,
    Widget Function(Spot spot)? cellBuilder,
    String? tooltip,
    bool isLastRow = false,
  }) {
    final spotEnabled = isSpotEnabled ?? (_) => true;
    final divider = BorderSide(color: colorScheme.outlineVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLastRow ? null : Border(bottom: divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: labelWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(right: divider)),
                child: _buildTableLabelCell(label, tooltip: tooltip),
              ),
            ),
            RadioGroup<String>(
              groupValue: groupValue,
              onChanged: (value) {
                if (value == null) return;
                final spot = spots.firstWhere(
                  (candidate) => candidate.id == value,
                );
                if (!spotEnabled(spot)) return;
                onChanged(value);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spots.map((spot) {
                  final spotId = spot.id!;
                  final enabled = spotEnabled(spot);
                  final selected = enabled && groupValue == spotId;
                  return SizedBox(
                    width: spotColumnWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border(right: divider)),
                      child: _wrapIncludedSpotColumn(
                        spotId,
                        colorScheme,
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: RadioListTile<String>(
                              value: spotId,
                              enabled: enabled,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              visualDensity: VisualDensity.compact,
                              title: DefaultTextStyle(
                                style: TextStyle(
                                  color: selected
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                child:
                                    cellBuilder?.call(spot) ??
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openImageGallery(
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (imageUrls.isEmpty) return;
    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => DetailNetworkGalleryViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
        ),
      ),
    );
  }

  Widget _buildClickablePhotoThumbnail(
    String imageUrl,
    List<String> allUrls,
    int index, {
    double size = 44,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openImageGallery(allUrls, index),
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ResizedSpotImage(
            imageUrl: imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildSpotPhotoPreviews(Spot spot) {
    final urls = spot.imageUrls ?? const [];
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < urls.length; i++)
            _buildClickablePhotoThumbnail(urls[i], urls, i),
        ],
      ),
    );
  }

  Widget _buildMediaGridRow({
    required String label,
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required List<Spot> spots,
    required Set<String> selectedIds,
    required int Function(Spot spot) countFor,
    required bool Function(Spot spot) hasMedia,
    Widget Function(Spot spot)? previewBuilder,
    bool isLastRow = false,
  }) {
    return _buildComparisonGridRow(
      labelWidth: labelWidth,
      spotColumnWidth: spotColumnWidth,
      colorScheme: colorScheme,
      isLastRow: isLastRow,
      label: _buildTableLabelCell(label),
      spotCells: spots.map((spot) {
        final spotId = spot.id!;
        final count = countFor(spot);
        final included = _isSpotIncludedInMerge(spot);
        final cell = !hasMedia(spot)
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'None',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: included && selectedIds.contains(spotId),
                      onChanged: included
                          ? (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  selectedIds.add(spotId);
                                } else {
                                  selectedIds.remove(spotId);
                                }
                                _afterMergeSelectionChanged(spots);
                              });
                            }
                          : null,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text('$count ${count == 1 ? 'item' : 'items'}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (previewBuilder != null) previewBuilder(spot),
                  ],
                ),
              );
        return _wrapIncludedSpotColumn(spotId, colorScheme, cell);
      }).toList(),
    );
  }

  Widget _buildComparisonGridRowShell({
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required Widget label,
    required List<Widget> spotCells,
    Color? backgroundColor,
    bool isLastRow = false,
  }) {
    final divider = BorderSide(color: colorScheme.outlineVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isLastRow ? null : Border(bottom: divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: labelWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(right: divider)),
                child: label,
              ),
            ),
            ...spotCells.map((cell) {
              return SizedBox(
                width: spotColumnWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(right: divider)),
                  child: cell,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableLabelCell(String label, {String? tooltip}) {
    final text = Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: tooltip == null
          ? text
          : Tooltip(message: tooltip, child: text),
    );
  }

  Widget _buildThumbnail(Spot spot, {double size = 72}) {
    final imageUrl = spot.imageUrls?.firstOrNull;
    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
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
        width: size,
        height: size,
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

  Widget _buildAccessSummary(Spot spot) {
    if (spot.spotAccess == null) {
      return _detailLine(Icons.lock_outline, 'No access');
    }
    return _smallChip(SpotAttributes.getLabel('access', spot.spotAccess!));
  }

  Widget _buildFacilitiesSummary(Spot spot) {
    final chips = <Widget>[];
    spot.spotFacilities?.forEach((key, value) {
      if (value == 'true') {
        chips.add(_smallChip(SpotAttributes.getLabel('facilities', key)));
      }
    });
    if (chips.isEmpty) {
      return _detailLine(Icons.home_work_outlined, 'No facilities');
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips.take(8).toList());
  }

  Widget _buildFeaturesSummary(Spot spot) {
    final chips = (spot.spotFeatures ?? <String>[])
        .map((key) => _smallChip(SpotAttributes.getLabel('features', key)))
        .toList();
    if (chips.isEmpty) {
      return _detailLine(Icons.tune, 'No features');
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips.take(8).toList());
  }

  Widget _buildGoodForSummary(Spot spot) {
    final chips = (spot.goodFor ?? <String>[])
        .map((key) => _smallChip(SpotAttributes.getLabel('goodFor', key)))
        .toList();
    if (chips.isEmpty) {
      return _detailLine(Icons.tune, 'No good-for tags');
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips.take(8).toList());
  }

  Widget _buildAdditiveAttributeGridRow({
    required String label,
    required double labelWidth,
    required double spotColumnWidth,
    required ColorScheme colorScheme,
    required List<Spot> spots,
    required Set<String> selectedIds,
    required int Function(Spot spot) countFor,
    required String emptyLabel,
    required Widget Function(Spot spot) summaryBuilder,
    String? tooltip,
    bool isLastRow = false,
  }) {
    return _buildComparisonGridRow(
      labelWidth: labelWidth,
      spotColumnWidth: spotColumnWidth,
      colorScheme: colorScheme,
      isLastRow: isLastRow,
      label: _buildTableLabelCell(label, tooltip: tooltip),
      spotCells: spots.map((spot) {
        final spotId = spot.id!;
        final included = _isSpotIncludedInMerge(spot);
        final count = countFor(spot);
        final cell = Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: included && selectedIds.contains(spotId),
                onChanged: included
                    ? (checked) {
                        setState(() {
                          if (checked ?? false) {
                            selectedIds.add(spotId);
                          } else {
                            selectedIds.remove(spotId);
                          }
                          _afterMergeSelectionChanged(spots);
                        });
                      }
                    : null,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  count == 0
                      ? emptyLabel
                      : '$count ${count == 1 ? 'tag' : 'tags'}',
                ),
                visualDensity: VisualDensity.compact,
              ),
              summaryBuilder(spot),
            ],
          ),
        );
        return _wrapIncludedSpotColumn(spotId, colorScheme, cell);
      }).toList(),
    );
  }

  Widget _smallChip(String label) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildPreviewPanel(Spot preview, List<Spot> spots) {
    if (_isEditingPreview) {
      return _buildEditablePreviewPanel(preview);
    }
    return _buildReadOnlyPreviewPanel(preview, spots);
  }

  Widget _buildReadOnlyPreviewPanel(Spot preview, List<Spot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Result preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _enterPreviewEditMode(spots),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
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
              '${preview.latitude.toStringAsFixed(6)}, '
              '${preview.longitude.toStringAsFixed(6)}',
            ),
            _detailLine(
              Icons.photo_library,
              '${preview.imageUrls?.length ?? 0} photos · '
              '${preview.youtubeVideoIds?.length ?? 0} videos',
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
                    return _buildClickablePhotoThumbnail(
                      preview.imageUrls![index],
                      preview.imageUrls!,
                      index,
                      size: 84,
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

  Widget _buildEditablePreviewPanel(Spot preview) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
                            'Result preview',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fine-tune the merged spot before resolving.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _exitPreviewEditMode,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _previewNameController,
                  labelText: 'Spot Name',
                  hintText: 'Enter the name of the spot',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _previewDescriptionController,
                  labelText: 'Description',
                  hintText:
                      'Describe the spot, what makes it special, etc.',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SpotImageSection(
          selectedImageBytes: const [],
          existingImageUrls: _previewImageUrls,
          onPickFromGallery: () {},
          onTakePhoto: () {},
          onRemoveSelectedAt: (_) {},
          onRemoveExistingAt: _removePreviewImageAt,
          onReorderExisting: _reorderPreviewImage,
          sectionTitle: 'Photos',
          showRequiredIndicator: false,
          showAddButtons: false,
        ),
        const SizedBox(height: 16),
        SpotAttributesSection(
          selectedAccess: _previewAccess,
          selectedFeatures: _previewFeatures,
          selectedFacilities: _previewFacilities,
          selectedGoodFor: _previewGoodFor,
          onAccessChanged: _onPreviewAccessChanged,
          onToggleFeature: _togglePreviewFeature,
          onFacilityChanged: _onPreviewFacilityChanged,
          onToggleGoodFor: _togglePreviewGoodFor,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Other merged details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _detailLine(Icons.place, _locationLabel(preview)),
                _detailLine(
                  Icons.gps_fixed,
                  '${preview.latitude.toStringAsFixed(6)}, '
                  '${preview.longitude.toStringAsFixed(6)}',
                ),
                _detailLine(
                  Icons.ondemand_video,
                  '${preview.youtubeVideoIds?.length ?? 0} '
                  '${(preview.youtubeVideoIds?.length ?? 0) == 1 ? 'video' : 'videos'}',
                ),
              ],
            ),
          ),
        ),
      ],
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
      if (value == 'true' || value == 'yes') {
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

  Widget _buildConfirmPanel(
    _DuplicateClusterReviewData data, {
    required int mergePairCount,
  }) {
    final authService = context.watch<AuthService>();
    final hasAlreadyDuplicateIncluded = data.spots.any(
      (spot) =>
          _includedSpotIds.contains(spot.id) &&
          isSpotAlreadyMarkedAsDuplicate(spot),
    );
    final canResolve =
        !_isResolving &&
        _resolvedNativeSpotId == null &&
        _includedSpotIds.length >= 2 &&
        !hasAlreadyDuplicateIncluded;
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
            if (_includedSpotIds.length < 2) ...[
              const SizedBox(height: 8),
              Text(
                'Include at least two spots to create a native merge.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (hasAlreadyDuplicateIncluded) ...[
              const SizedBox(height: 8),
              Text(
                'Remove spots that are already marked as duplicates of another spot.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
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
                    ? () => _confirmResolution(
                        data,
                        authService,
                        mergePairCount: mergePairCount,
                      )
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

  Widget _buildResolutionConfirmRow({
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: valueStyle ?? theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionConfirmContent({
    required Spot preview,
    required int includedCount,
    required int unchangedCount,
    required int mergePairCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final spotNameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review the outcome before resolving.', style: mutedStyle),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResolutionConfirmRow(
                icon: Icons.add_location_alt_outlined,
                label: 'New native spot',
                value: preview.name,
                valueStyle: spotNameStyle,
              ),
              const SizedBox(height: 10),
              _buildResolutionConfirmRow(
                icon: Icons.link,
                label: 'Marked as duplicates',
                value: '$includedCount spot${includedCount == 1 ? '' : 's'}',
                valueStyle: valueStyle,
              ),
              if (unchangedCount > 0) ...[
                const SizedBox(height: 10),
                _buildResolutionConfirmRow(
                  icon: Icons.remove_circle_outline,
                  label: 'Left unchanged',
                  value:
                      '$unchangedCount spot${unchangedCount == 1 ? '' : 's'}',
                  valueStyle: valueStyle,
                ),
              ],
              const SizedBox(height: 10),
              _buildResolutionConfirmRow(
                icon: Icons.done_all,
                label: 'Detection pairs resolved',
                value: '$mergePairCount pair${mergePairCount == 1 ? '' : 's'}',
                valueStyle: valueStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResolution(
    _DuplicateClusterReviewData data,
    AuthService authService, {
    required int mergePairCount,
  }) async {
    final includedSpots = _includedSpots(data.spots);
    final preview = _buildPreview(includedSpots);
    final includedCount = includedSpots.length;
    final unchangedCount = data.spots.length - includedCount;
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      _showSnack('You must be signed in to resolve duplicate clusters.');
      return;
    }
    if (includedSpots.any(isSpotAlreadyMarkedAsDuplicate)) {
      _showSnack(
        'Cannot merge spots that are already marked as duplicates of another spot.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve duplicate cluster?'),
        content: _buildResolutionConfirmContent(
          preview: preview,
          includedCount: includedCount,
          unchangedCount: unchangedCount,
          mergePairCount: mergePairCount,
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
      clusterSpots: includedSpots,
      previewSpot: preview,
      userId: currentUser.uid,
      userName: userName,
      runId: data.runId,
      resolvedPairIndices: _resolvedPairIndicesForMerge(data),
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
  static const int _selectedMarkerZBase = 1000;
  static const double _coincidentPinSpreadMeters = 7;
  static const double _minZoom = 3;
  static const double _maxZoom = 21;

  bool _isSatelliteView = true;
  double? _currentZoom;
  GoogleMapController? _mapController;
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
    if (span > 25) return 16;
    return 18;
  }

  Map<String, LatLng> _spreadMarkerPositions(List<Spot> spots) {
    final groups = <String, List<Spot>>{};
    for (final spot in spots) {
      final key =
          '${spot.latitude.toStringAsFixed(7)}|${spot.longitude.toStringAsFixed(7)}';
      groups.putIfAbsent(key, () => []).add(spot);
    }

    final positions = <String, LatLng>{};
    for (final group in groups.values) {
      if (group.length == 1) {
        final spot = group.first;
        if (spot.id != null) {
          positions[spot.id!] = LatLng(spot.latitude, spot.longitude);
        }
        continue;
      }

      group.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
      final center = LatLng(group.first.latitude, group.first.longitude);
      for (var i = 0; i < group.length; i++) {
        final spot = group[i];
        final spotId = spot.id;
        if (spotId == null) continue;
        positions[spotId] = _offsetCoincidentPin(
          center: center,
          index: i,
          count: group.length,
        );
      }
    }
    return positions;
  }

  LatLng _offsetCoincidentPin({
    required LatLng center,
    required int index,
    required int count,
  }) {
    if (count <= 1) return center;

    final angle = (2 * math.pi * index) / count;
    final latOffset =
        _coincidentPinSpreadMeters * math.cos(angle) / 111000.0;
    final cosLat = math.cos(center.latitude * math.pi / 180.0).abs();
    final lngOffset = cosLat < 0.000001
        ? 0.0
        : _coincidentPinSpreadMeters * math.sin(angle) / (111000.0 * cosLat);
    return LatLng(
      center.latitude + latOffset,
      center.longitude + lngOffset,
    );
  }

  Set<Marker> _markers() {
    final displayPositions = _spreadMarkerPositions(widget.spots);
    final drawOrder = MarkerIconUtils.sortSpotsForMapDrawOrder(widget.spots);
    final markers = <Marker>{};

    for (var i = 0; i < drawOrder.length; i++) {
      final spot = drawOrder[i];
      final spotId = spot.id;
      if (spotId == null) continue;

      final selected = spotId == widget.selectedLocationSpotId;
      final position = displayPositions[spotId] ??
          LatLng(spot.latitude, spot.longitude);
      markers.add(
        Marker(
          markerId: MarkerId(spotId),
          position: position,
          infoWindow: InfoWindow(
            title: spot.name,
            snippet:
                spot.spotSourceName ?? spot.spotSource ?? 'Native parkour.spot',
          ),
          icon: selected
              ? (_selectedPinIcon ?? BitmapDescriptor.defaultMarker)
              : (_normalPinIcon ?? BitmapDescriptor.defaultMarker),
          anchor: const Offset(0.5, 1.0),
          zIndexInt: selected ? _selectedMarkerZBase + i : i,
        ),
      );
    }
    return markers;
  }

  Future<void> _changeZoom(double delta) async {
    final controller = _mapController;
    if (controller == null) return;

    var zoom = _currentZoom ?? _cameraZoom;
    try {
      zoom = await controller.getZoomLevel();
    } catch (_) {}

    final nextZoom = (zoom + delta).clamp(_minZoom, _maxZoom);
    _currentZoom = nextZoom;
    await controller.animateCamera(CameraUpdate.zoomTo(nextZoom));
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
                'duplicate_cluster_${widget.spots.map((spot) => spot.id).join('_')}',
              ),
              initialCameraPosition: CameraPosition(
                target: _cameraTarget,
                zoom: _cameraZoom,
              ),
              mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
              markers: _markers(),
              onMapCreated: (controller) {
                _mapController = controller;
                _currentZoom = _cameraZoom;
              },
              onCameraMove: (position) => _currentZoom = position.zoom,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              webCameraControlEnabled: false,
              compassEnabled: false,
              tiltGesturesEnabled: false,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _changeZoom(1),
                      tooltip: 'Zoom in',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                    IconButton(
                      onPressed: () => _changeZoom(-1),
                      tooltip: 'Zoom out',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
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
                      '${widget.spots.length} cluster pins · location row highlights map pin',
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
