import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_config.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/search_state_service.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/marker_icon_utils.dart';
import '../../l10n/app_localizations.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final bool showUsageTip;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.showUsageTip = false,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const double _kMaxContentWidth = 1200;

  LatLng? _pickedLocation;
  bool _isSatelliteView = false;
  bool _isGettingLocation = false;
  GoogleMapController? _mapController;
  SearchStateService? _searchStateServiceRef;
  BitmapDescriptor? _pickedLocationPinIcon;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _loadPickedLocationPinIcon();

    // Initialize satellite view from SearchStateService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() {
        _isSatelliteView = _searchStateServiceRef!.isSatellite;
      });
    });
  }

  Future<void> _loadPickedLocationPinIcon() async {
    final BitmapDescriptor icon =
        await MarkerIconUtils.loadNormalSelectedMapPin();
    if (mounted) {
      setState(() => _pickedLocationPinIcon = icon);
    }
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;

    setState(() {
      _isSatelliteView = searchState.isSatellite;
    });
  }

  @override
  void dispose() {
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    final position =
        await LocationPermissionUtils.getCurrentPositionWithPermission(
          context: context,
          showErrorMessages: true,
          accuracy: LocationAccuracy.high,
        );

    if (mounted && position != null) {
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _pickedLocation = location;
      });
      // Move camera to user location if map is ready
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: location, zoom: 16),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final CameraPosition initialCameraPosition = CameraPosition(
      target:
          widget.initialLocation ??
          const LatLng(
            AppConfig.defaultMapCenterLat,
            AppConfig.defaultMapCenterLng,
          ),
      zoom: widget.initialLocation != null ? 16 : 10,
    );

    final tipText = MobileDetectionService.isMobileDevice
        ? l10n.addSpotTipLongPressMobile
        : l10n.addSpotTipRightClickDesktop;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppBar(
                    title: Text(l10n.addSpotPickLocationAppBarTitle),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go('/explore');
                        }
                      },
                    ),
                    automaticallyImplyLeading: false,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showUsageTip)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    tipText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: kIsWeb,
                  compassEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: (LatLng position) {
                    setState(() {
                      _pickedLocation = position;
                    });
                  },
                  markers: _pickedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _pickedLocation!,
                            icon: _pickedLocationPinIcon ??
                                BitmapDescriptor.defaultMarker,
                            anchor: const Offset(0.5, 1.0),
                            draggable: true,
                            onDragEnd: (LatLng position) {
                              setState(() {
                                _pickedLocation = position;
                              });
                            },
                          ),
                        },
                ),
                // Map Type Toggle Button - Floating Action Button
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final rightPosition = screenWidth > _kMaxContentWidth
                        ? (screenWidth - _kMaxContentWidth) / 2 + 16
                        : 16.0;
                    return Positioned(
                      bottom: 88,
                      right: rightPosition,
                      child: PointerInterceptor(
                        child: FloatingActionButton(
                          onPressed: () {
                            setState(() {
                              _isSatelliteView = !_isSatelliteView;
                            });
                            final searchState = Provider.of<SearchStateService>(
                              context,
                              listen: false,
                            );
                            searchState.setSatellite(_isSatelliteView);
                          },
                          heroTag: 'mapTypeToggleFab',
                          mini: true,
                          tooltip: _isSatelliteView
                              ? l10n.exploreSwitchToMap
                              : l10n.exploreSwitchToSatellite,
                          child: Icon(
                            _isSatelliteView ? Icons.map : Icons.terrain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Find my location button - Floating Action Button
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final rightPosition = screenWidth > _kMaxContentWidth
                        ? (screenWidth - _kMaxContentWidth) / 2 + 16
                        : 16.0;
                    return Positioned(
                      bottom: 24,
                      right: rightPosition,
                      child: PointerInterceptor(
                        child: FloatingActionButton(
                          onPressed: _getCurrentLocation,
                          heroTag: 'currentLocationFab',
                          mini: true,
                          tooltip: l10n.exploreCenterOnMyLocation,
                          child: _isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ),
                    );
                  },
                ),
                // Use this location button - Bottom center
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: PointerInterceptor(
                      child: FloatingActionButton.extended(
                        onPressed: _pickedLocation == null
                            ? null
                            : () {
                                Navigator.pop(context, _pickedLocation);
                              },
                        icon: const Icon(Icons.check),
                        label: Text(l10n.addSpotUseThisLocation),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
