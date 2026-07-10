import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/event_map_pin.dart';
import '../models/parkour_event.dart';
import '../services/event_map_service.dart';
import '../services/mobile_detection_service.dart';
import '../services/search_state_service.dart';
import '../utils/event_locate_utils.dart';
import '../utils/map_bounds_utils.dart';
import '../utils/marker_icon_utils.dart';

/// Inline map preview for event detail: venue and linked spot pins.
class EventLocationMapPreview extends StatefulWidget {
  const EventLocationMapPreview({
    super.key,
    required this.event,
    required this.isSatelliteViewNotifier,
    required this.onTap,
    this.mapHeroTagPrefix = 'eventDetail',
  });

  final ParkourEvent event;
  final ValueNotifier<bool> isSatelliteViewNotifier;
  final VoidCallback onTap;
  final String mapHeroTagPrefix;

  @override
  State<EventLocationMapPreview> createState() => _EventLocationMapPreviewState();
}

class _EventLocationMapPreviewState extends State<EventLocationMapPreview> {
  Future<List<EventMapPin>>? _pinsFuture;
  GoogleMapController? _mapController;
  BitmapDescriptor? _eventMapPinIcon;
  BitmapDescriptor? _spotMapPinIcon;

  @override
  void initState() {
    super.initState();
    _pinsFuture = _loadPins();
    _loadMarkerIcons();
  }

  @override
  void didUpdateWidget(covariant EventLocationMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.latitude != widget.event.latitude ||
        oldWidget.event.longitude != widget.event.longitude ||
        oldWidget.event.spotIds.join(',') != widget.event.spotIds.join(',') ||
        oldWidget.event.spotListIds.join(',') !=
            widget.event.spotListIds.join(',')) {
      _pinsFuture = _loadPins();
    }
  }

  Future<List<EventMapPin>> _loadPins() {
    final eventMapService = context.read<EventMapService>();
    return resolveEventDetailMapPins(
      event: widget.event,
      firestore: eventMapService.firestore,
      getMapPinsForEvent: eventMapService.getMapPinsForEvent,
    );
  }

  Future<void> _loadMarkerIcons() async {
    final double pinHeight = MarkerIconUtils.mapPinSingleSpotLogicalHeight;
    final results = await Future.wait([
      MarkerIconUtils.loadEventMapPin(logicalHeight: pinHeight),
      MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinNormalAsset,
        fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
        logicalHeight: pinHeight,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _eventMapPinIcon = results[0];
      _spotMapPinIcon = results[1];
    });
  }

  LatLngBounds? _boundsForPins(List<EventMapPin> pins) {
    return calculateBoundsForLatLngs(
      pins.map((pin) => LatLng(pin.latitude, pin.longitude)),
    );
  }

  CameraPosition? _initialCameraPosition(List<EventMapPin> pins) {
    if (pins.isEmpty) return null;

    if (pins.length == 1) {
      final pin = pins.first;
      return CameraPosition(
        target: LatLng(pin.latitude, pin.longitude),
        zoom: 16,
      );
    }

    final bounds = _boundsForPins(pins);
    if (bounds == null) return null;

    final centerLat =
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final centerLng =
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 10;
    if (maxDiff > 0.1) {
      zoom = 8;
    } else if (maxDiff > 0.05) {
      zoom = 9;
    } else if (maxDiff > 0.01) {
      zoom = 11;
    } else if (maxDiff > 0.005) {
      zoom = 12;
    } else {
      zoom = 13;
    }

    return CameraPosition(target: LatLng(centerLat, centerLng), zoom: zoom);
  }

  Future<void> _fitBounds(List<EventMapPin> pins) async {
    if (_mapController == null || pins.length < 2) return;
    final bounds = _boundsForPins(pins);
    if (bounds == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  Set<Marker> _buildMarkers(List<EventMapPin> pins) {
    final ordered = MarkerIconUtils.sortByLatitudeNorthFirst(
      pins,
      (pin) => pin.latitude,
    );

    return ordered.map((pin) {
      final icon = pin.kind == EventMapPinKind.venue
          ? (_eventMapPinIcon ?? BitmapDescriptor.defaultMarker)
          : (_spotMapPinIcon ?? BitmapDescriptor.defaultMarker);

      return Marker(
        markerId: MarkerId(pin.id),
        position: LatLng(pin.latitude, pin.longitude),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: null,
        consumeTapEvents: true,
        infoWindow: InfoWindow.noText,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<List<EventMapPin>>(
      future: _pinsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
            ),
          );
        }

        final pins = snapshot.data ?? const <EventMapPin>[];
        if (pins.isEmpty) return const SizedBox.shrink();

        final initialCamera = _initialCameraPosition(pins);
        if (initialCamera == null) return const SizedBox.shrink();

        final showPinCount = pins.length > 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.isSatelliteViewNotifier,
                    builder: (context, isSatellite, child) {
                      return GoogleMap(
                        initialCameraPosition: initialCamera,
                        mapType: isSatellite ? MapType.hybrid : MapType.normal,
                        markers: _buildMarkers(pins),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitBounds(pins);
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
                        indoorViewEnabled: false,
                        trafficEnabled: false,
                      );
                    },
                  ),
                  Positioned.fill(
                    child: PointerInterceptor(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onTap,
                          borderRadius: BorderRadius.circular(
                            SpotDetailUi.surfaceRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 10,
                    child: PointerInterceptor(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: widget.isSatelliteViewNotifier,
                        builder: (context, isSatellite, child) {
                          return FloatingActionButton(
                            onPressed: () {
                              widget.isSatelliteViewNotifier.value =
                                  !isSatellite;
                              final searchState =
                                  Provider.of<SearchStateService>(
                                    context,
                                    listen: false,
                                  );
                              searchState.setSatellite(
                                widget.isSatelliteViewNotifier.value,
                              );
                            },
                            heroTag: '${widget.mapHeroTagPrefix}MapTypeToggleFab',
                            mini: true,
                            tooltip: isSatellite
                                ? l10n.spotDetailMapSwitchToMap
                                : l10n.spotDetailMapSwitchToSatellite,
                            child: Icon(isSatellite ? Icons.map : Icons.terrain),
                          );
                        },
                      ),
                    ),
                  ),
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
                              l10n.spotDetailMapLocateOnMap,
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
                  if (showPinCount)
                    Positioned(
                      top: 8,
                      left: 8,
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
                          child: Text(
                            l10n.exploreSpotCountShort(pins.length),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
