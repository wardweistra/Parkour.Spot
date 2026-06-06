import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/marker_icon_utils.dart';

/// Read-only map for moderators reviewing a proposed location change.
///
/// Shows one pin for a new location, or current vs suggested pins when both
/// coordinates are provided.
class LocationReviewMap extends StatefulWidget {
  const LocationReviewMap({
    super.key,
    this.current,
    this.suggested,
    this.height = 220,
    this.showSatelliteToggle = true,
    this.interactive = true,
  }) : assert(
         current != null || suggested != null,
         'Provide at least one of current or suggested',
       );

  final LatLng? current;
  final LatLng? suggested;
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

  bool get _isComparison =>
      widget.current != null &&
      widget.suggested != null &&
      (widget.current!.latitude != widget.suggested!.latitude ||
          widget.current!.longitude != widget.suggested!.longitude);

  LatLng get _cameraTarget {
    if (_isComparison) {
      return LatLng(
        (widget.current!.latitude + widget.suggested!.latitude) / 2,
        (widget.current!.longitude + widget.suggested!.longitude) / 2,
      );
    }
    return widget.suggested ?? widget.current!;
  }

  double get _cameraZoom {
    if (!_isComparison) return 16;

    final latSpan = (widget.current!.latitude - widget.suggested!.latitude)
        .abs();
    final lngSpan = (widget.current!.longitude - widget.suggested!.longitude)
        .abs();
    final span = (latSpan > lngSpan ? latSpan : lngSpan) * 111000;
    if (span > 10000) return 10;
    if (span > 5000) return 11;
    if (span > 2000) return 12;
    if (span > 500) return 14;
    return 16;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.current != null && (_isComparison || widget.suggested == null)) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: widget.current!,
          infoWindow: const InfoWindow(
            title: 'Current',
            snippet: 'Existing location',
          ),
          icon: _currentPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 0,
        ),
      );
    }

    if (widget.suggested != null && (_isComparison || widget.current == null)) {
      markers.add(
        Marker(
          markerId: const MarkerId('suggested'),
          position: widget.suggested!,
          infoWindow: InfoWindow(
            title: _isComparison ? 'Suggested' : 'Location',
            snippet: _isComparison
                ? 'Proposed location'
                : 'Proposed location',
          ),
          icon: _suggestedPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 1,
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
                'location_review_${widget.current?.latitude}_${widget.current?.longitude}_${widget.suggested?.latitude}_${widget.suggested?.longitude}',
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
                      'locationReviewMapType_${widget.current?.latitude}_${widget.suggested?.latitude}',
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
                        _legendDot(theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Current', style: theme.textTheme.labelSmall),
                        const SizedBox(width: 12),
                        _legendDot(theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Suggested', style: theme.textTheme.labelSmall),
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

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
