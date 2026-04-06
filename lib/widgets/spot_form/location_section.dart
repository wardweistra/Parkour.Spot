import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../services/mobile_detection_service.dart';
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
  });

  @override
  State<SpotLocationSection> createState() => _SpotLocationSectionState();
}

class _SpotLocationSectionState extends State<SpotLocationSection> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.addSpotLocationSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '*',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected_location'),
                          position: widget.currentLocation!,
                          infoWindow: InfoWindow.noText,
                        ),
                      },
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
                          heroTag: 'mapTypeToggleFab',
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
                          heroTag: 'currentLocationFab',
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
        ),
      ),
    );
  }
}

