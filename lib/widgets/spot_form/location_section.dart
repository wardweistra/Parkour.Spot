import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpotLocationSection extends StatefulWidget {
  final LatLng? currentLocation;
  final String? address;
  final bool isGettingLocation;
  final bool isGeocoding;
  final bool isSatelliteView;
  final void Function() onRefreshLocation;
  final void Function() onPickOnMap;
  final void Function(bool) onToggleSatellite;

  const SpotLocationSection({
    super.key,
    required this.currentLocation,
    required this.address,
    required this.isGettingLocation,
    required this.isGeocoding,
    required this.isSatelliteView,
    required this.onRefreshLocation,
    required this.onPickOnMap,
    required this.onToggleSatellite,
  });

  @override
  State<SpotLocationSection> createState() => _SpotLocationSectionState();
}

class _SpotLocationSectionState extends State<SpotLocationSection> {

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '*',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.isGettingLocation)
              const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('Getting your location...'),
                ],
              )
            else if (widget.currentLocation != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${widget.currentLocation!.latitude.toStringAsFixed(6)}, ${widget.currentLocation!.longitude.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                                if (widget.address != null) ...[
                                  TextSpan(
                                    text: '\n${widget.address}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.isGeocoding) ...[
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Getting address...',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_fixed,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Location selected',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
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
                      'Location not available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.currentLocation != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Location Preview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Standard',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: !widget.isSatelliteView
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                            ),
                      ),
                      Switch(
                        value: widget.isSatelliteView,
                        onChanged: widget.onToggleSatellite,
                      ),
                      Text(
                        'Satellite',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: widget.isSatelliteView
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.currentLocation!,
                    zoom: 16,
                  ),
                  mapType: widget.isSatelliteView ? MapType.satellite : MapType.normal,
                  onMapCreated: (controller) {},
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
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.isGettingLocation ? null : widget.onRefreshLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Location'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onPickOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


