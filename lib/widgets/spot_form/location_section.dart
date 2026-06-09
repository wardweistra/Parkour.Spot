import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/spot.dart';
import '../../services/mobile_detection_service.dart';
import '../../utils/marker_icon_utils.dart';
import '../../widgets/location_info_box.dart';
import '../../l10n/app_localizations.dart';

class SpotLocationSection extends StatefulWidget {
  final LatLng? currentLocation;
  final String? address;
  final String? countryCode;
  final bool isGettingLocation;
  final bool isGeocoding;
  final bool isSatelliteView;
  final bool isLocationPermissionDenied;
  final void Function() onRefreshLocation;
  final void Function() onPickOnMap;
  final void Function(bool) onToggleSatellite;
  final void Function(GoogleMapController)? onMapCreated;
  final String? sectionTitle;
  final String? sectionSubtitle;
  final bool showRequiredIndicator;
  final bool embedded;
  final String mapHeroTagPrefix;
  final bool showSelectedPin;
  final bool showLocationDetails;
  final List<Spot> linkedSpots;

  const SpotLocationSection({
    super.key,
    required this.currentLocation,
    required this.address,
    this.countryCode,
    required this.isGettingLocation,
    required this.isGeocoding,
    required this.isSatelliteView,
    this.isLocationPermissionDenied = false,
    required this.onRefreshLocation,
    required this.onPickOnMap,
    required this.onToggleSatellite,
    this.onMapCreated,
    this.sectionTitle,
    this.sectionSubtitle,
    this.showRequiredIndicator = true,
    this.embedded = false,
    this.mapHeroTagPrefix = 'spotForm',
    this.showSelectedPin = true,
    this.showLocationDetails = true,
    this.linkedSpots = const <Spot>[],
  });

  @override
  State<SpotLocationSection> createState() => _SpotLocationSectionState();
}

class _SpotLocationSectionState extends State<SpotLocationSection> {
  BitmapDescriptor? _locationPinIcon;
  BitmapDescriptor? _linkedSpotPinIcon;

  @override
  void initState() {
    super.initState();
    _loadPinIcons();
  }

  Future<void> _loadPinIcons() async {
    final double pinHeight = MarkerIconUtils.mapPinSingleSpotLogicalHeight;
    final BitmapDescriptor locationIcon =
        await MarkerIconUtils.loadNormalSelectedMapPin();
    final BitmapDescriptor linkedSpotIcon = await MarkerIconUtils.loadMapPinPng(
      MarkerIconUtils.mapPinNormalAsset,
      fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
      logicalHeight: pinHeight,
    );
    if (mounted) {
      setState(() {
        _locationPinIcon = locationIcon;
        _linkedSpotPinIcon = linkedSpotIcon;
      });
    }
  }

  bool _spotHasCoordinates(Spot spot) =>
      spot.latitude != 0 || spot.longitude != 0;

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.showSelectedPin && widget.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: widget.currentLocation!,
          icon: _locationPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow.noText,
          zIndexInt: 1000,
        ),
      );
    }

    final linkedSpots = widget.linkedSpots
        .where(_spotHasCoordinates)
        .toList(growable: false);
    final orderedSpots = MarkerIconUtils.sortSpotsForMapDrawOrder(linkedSpots);
    for (var i = 0; i < orderedSpots.length; i++) {
      final spot = orderedSpots[i];
      markers.add(
        Marker(
          markerId: MarkerId('linked_spot_${spot.id ?? spot.name}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon: _linkedSpotPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(title: spot.name),
          zIndexInt: i,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        widget.sectionTitle ?? l10n.addSpotLocationSectionTitle;
    final showTitle = widget.embedded
        ? widget.sectionTitle != null
        : true;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (widget.showRequiredIndicator) ...[
                const SizedBox(width: 8),
                Text(
                  '*',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
          if (widget.sectionSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.sectionSubtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (widget.isGettingLocation)
              Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 12),
                  Text(l10n.addSpotGettingLocation),
                ],
              )
            else if (widget.currentLocation == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.addSpotLocationNotAvailable,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.currentLocation != null) ...[
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.currentLocation!,
                        zoom: 16,
                      ),
                      mapType: widget.isSatelliteView ? MapType.hybrid : MapType.normal,
                      onMapCreated: widget.onMapCreated,
                      markers: _buildMarkers(),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      liteModeEnabled: kIsWeb,
                      compassEnabled: false,
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      onTap: (_) => widget.onPickOnMap(),
                    ),
                    // Pick Location hint
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PointerInterceptor(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                MobileDetectionService.isMobileDevice
                                    ? Icons.phone_android
                                    : Icons.touch_app,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.addSpotPickLocationHint,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Map Type Toggle Button - Floating Action Button
                    Positioned(
                      bottom: 88,
                      right: 10,
                      child: PointerInterceptor(
                        child: FloatingActionButton(
                          onPressed: () {
                            widget.onToggleSatellite(!widget.isSatelliteView);
                          },
                          heroTag: '${widget.mapHeroTagPrefix}_mapTypeToggleFab',
                          mini: true,
                          tooltip: widget.isSatelliteView
                              ? l10n.exploreSwitchToMap
                              : l10n.exploreSwitchToSatellite,
                          child: Icon(
                            widget.isSatelliteView ? Icons.map : Icons.terrain,
                          ),
                        ),
                      ),
                    ),
                    // Center on my location button - Floating Action Button
                    Positioned(
                      bottom: 24,
                      right: 10,
                      child: PointerInterceptor(
                        child: FloatingActionButton(
                          onPressed: widget.isGettingLocation ? null : widget.onRefreshLocation,
                          heroTag: '${widget.mapHeroTagPrefix}_currentLocationFab',
                          mini: true,
                          tooltip: widget.isLocationPermissionDenied
                              ? l10n.exploreLocationPermissionDenied
                              : l10n.exploreCenterOnMyLocation,
                          child: widget.isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(widget.isLocationPermissionDenied 
                                  ? Icons.location_disabled 
                                  : Icons.my_location),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showLocationDetails) ...[
                const SizedBox(height: 16),
                LocationInfoBox(
                  latitude: widget.currentLocation!.latitude,
                  longitude: widget.currentLocation!.longitude,
                  address: widget.address,
                  countryCode: widget.countryCode,
                  isGeocoding: widget.isGeocoding,
                ),
              ],
            ],
      ],
    );

    if (widget.embedded) return content;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: content,
      ),
    );
  }
}

