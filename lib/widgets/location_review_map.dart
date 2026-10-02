import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../utils/marker_icon_utils.dart';

/// Read-only map for moderators reviewing a proposed location change.
///
/// Shows current and/or suggested pins using the same explore spot pin assets.
/// Prefer [currentPins]/[suggestedPins] for multi-point sides; the single
/// [current]/[suggested] fields remain as shortcuts.
class LocationReviewMap extends StatefulWidget {
  LocationReviewMap({
    super.key,
    this.current,
    this.suggested,
    this.currentPins = const <LatLng>[],
    this.suggestedPins = const <LatLng>[],
    this.height = 220,
    this.showSatelliteToggle = true,
    this.interactive = true,
  }) : assert(
         current != null ||
             suggested != null ||
             currentPins.isNotEmpty ||
             suggestedPins.isNotEmpty,
         'Provide at least one current or suggested pin',
       );

  final LatLng? current;
  final LatLng? suggested;
  final List<LatLng> currentPins;
  final List<LatLng> suggestedPins;
  final double height;
  final bool showSatelliteToggle;
  final bool interactive;

  @override
  State<LocationReviewMap> createState() => _LocationReviewMapState();
}

class _LocationReviewMapState extends State<LocationReviewMap> {
  bool _isSatelliteView = false;
  BitmapDescriptor? _currentPinIcon;
  BitmapDescriptor? _suggestedPinIcon;

  List<LatLng> get _currentPins {
    return <LatLng>[
      if (widget.current != null) widget.current!,
      ...widget.currentPins,
    ];
  }

  List<LatLng> get _suggestedPins {
    return <LatLng>[
      if (widget.suggested != null) widget.suggested!,
      ...widget.suggestedPins,
    ];
  }

  bool get _isComparison =>
      _currentPins.isNotEmpty && _suggestedPins.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPinIcons();
  }

  Future<void> _loadPinIcons() async {
    final double h = MarkerIconUtils.mapPinSingleSpotLogicalHeight;
    final BitmapDescriptor current = await MarkerIconUtils.loadMapPinPng(
      MarkerIconUtils.mapPinNormalAsset,
      fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
      logicalHeight: h,
    );
    final BitmapDescriptor suggested = await MarkerIconUtils.loadMapPinPng(
      MarkerIconUtils.mapPinNormalSelectedAsset,
      fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
      logicalHeight: h,
    );
    if (!mounted) return;
    setState(() {
      _currentPinIcon = current;
      _suggestedPinIcon = suggested;
    });
  }

  List<LatLng> get _allPins => <LatLng>[..._currentPins, ..._suggestedPins];

  LatLng get _cameraTarget {
    final pins = _allPins;
    if (pins.isEmpty) return const LatLng(0, 0);
    if (pins.length == 1) return pins.first;
    var lat = 0.0;
    var lng = 0.0;
    for (final pin in pins) {
      lat += pin.latitude;
      lng += pin.longitude;
    }
    return LatLng(lat / pins.length, lng / pins.length);
  }

  double get _cameraZoom {
    final pins = _allPins;
    if (pins.length < 2) return 16;

    var minLat = pins.first.latitude;
    var maxLat = pins.first.latitude;
    var minLng = pins.first.longitude;
    var maxLng = pins.first.longitude;
    for (final pin in pins.skip(1)) {
      if (pin.latitude < minLat) minLat = pin.latitude;
      if (pin.latitude > maxLat) maxLat = pin.latitude;
      if (pin.longitude < minLng) minLng = pin.longitude;
      if (pin.longitude > maxLng) maxLng = pin.longitude;
    }
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final span = (latSpan > lngSpan ? latSpan : lngSpan) * 111000;
    if (span > 10000) return 10;
    if (span > 5000) return 11;
    if (span > 2000) return 12;
    if (span > 500) return 14;
    return 16;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final currentPins = _currentPins;
    final suggestedPins = _suggestedPins;
    final showCurrent = currentPins.isNotEmpty &&
        (_isComparison || suggestedPins.isEmpty);
    final showSuggested = suggestedPins.isNotEmpty &&
        (_isComparison || currentPins.isEmpty);

    if (showCurrent) {
      for (var i = 0; i < currentPins.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId('current_$i'),
            position: currentPins[i],
            infoWindow: InfoWindow(
              title: currentPins.length == 1
                  ? 'Current'
                  : 'Current ${i + 1}',
              snippet: 'Existing location',
            ),
            icon: _currentPinIcon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: i,
          ),
        );
      }
    }

    if (showSuggested) {
      for (var i = 0; i < suggestedPins.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId('suggested_$i'),
            position: suggestedPins[i],
            infoWindow: InfoWindow(
              title: !_isComparison
                  ? 'Location'
                  : suggestedPins.length == 1
                  ? 'Suggested'
                  : 'Suggested ${i + 1}',
              snippet: 'Proposed location',
            ),
            icon: _suggestedPinIcon ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: 100 + i,
          ),
        );
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              key: ValueKey(
                'location_review_${_currentPins.map((p) => '${p.latitude},${p.longitude}').join('|')}_${_suggestedPins.map((p) => '${p.latitude},${p.longitude}').join('|')}',
              ),
              initialCameraPosition: CameraPosition(
                target: _cameraTarget,
                zoom: _cameraZoom,
              ),
              mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
              markers: _buildMarkers(),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              webCameraControlEnabled: false,
              liteModeEnabled: kIsWeb,
              compassEnabled: false,
              zoomGesturesEnabled: widget.interactive,
              scrollGesturesEnabled: widget.interactive,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: widget.interactive,
            ),
            if (widget.showSatelliteToggle)
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() => _isSatelliteView = !_isSatelliteView);
                  },
                  heroTag:
                      'locationReviewMapType_${_cameraTarget.latitude}_${_cameraTarget.longitude}',
                  mini: true,
                  tooltip: _isSatelliteView ? 'Switch to Map' : 'Switch to Hybrid',
                  child: Icon(
                    _isSatelliteView ? Icons.map : Icons.terrain,
                  ),
                ),
              ),
            if (_isComparison)
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _legendPin(MarkerIconUtils.mapPinNormalAsset),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.locationReviewCurrentLabel ?? 'Current',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(width: 12),
                        _legendPin(MarkerIconUtils.mapPinNormalSelectedAsset),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.locationReviewSuggestedLabel ?? 'Suggested',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendPin(String assetPath) {
    return Image.asset(
      assetPath,
      height: 18,
      width: MarkerIconUtils.mapPinLogicalWidthForHeight(18),
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: MarkerIconUtils.mapPinNormalFallbackFill,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
