import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_map_pin.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/event_map_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/search_state_service.dart';
import '../../services/spot_service.dart';
import '../../utils/explore_events_utils.dart';
import '../../utils/explore_search_autocomplete.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/marker_icon_utils.dart';
import '../event_card.dart';
import '../spot_card.dart';
import 'explore_entity_picker_config.dart';
import 'explore_entity_picker_result.dart';

class ExploreEntityPickerScreen extends StatefulWidget {
  const ExploreEntityPickerScreen({super.key, required this.config});

  final ExploreEntityPickerConfig config;

  static Future<ExploreEntityPickerResult?> show(
    BuildContext context, {
    required ExploreEntityPickerConfig config,
  }) {
    return Navigator.of(context).push<ExploreEntityPickerResult>(
      MaterialPageRoute(
        builder: (_) => ExploreEntityPickerScreen(config: config),
      ),
    );
  }

  @override
  State<ExploreEntityPickerScreen> createState() =>
      _ExploreEntityPickerScreenState();
}

class _ExploreEntityPickerScreenState extends State<ExploreEntityPickerScreen> {
  static const double _kMaxContentWidth = 1200;
  static const int _selectedMarkerZBase = 8000;
  static const double _kPreviewPanelMaxWidth = 400;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  GoogleMapController? _mapController;
  SearchStateService? _searchStateServiceRef;
  Timer? _cameraDebounce;
  String? _placesSessionToken;
  double _lastKnownZoom = 14;

  LatLng? _pickedLocation;
  List<Spot> _loadedSpots = [];
  List<EventMapPin> _loadedEventPins = [];
  Set<Marker> _markers = {};

  Spot? _previewSpot;
  EventMapPin? _previewEventPin;

  bool _isSatelliteView = false;
  bool _isLoadingMapData = false;
  bool _isSearchingLocation = false;
  bool _isGettingLocation = false;
  bool _isConfirming = false;

  BitmapDescriptor? _spotDefaultIcon;
  BitmapDescriptor? _spotSelectedIcon;
  BitmapDescriptor? _eventIcon;
  BitmapDescriptor? _eventSelectedIcon;
  BitmapDescriptor? _pickedLocationPinIcon;

  ExploreEntityPickerConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    if (_config.includesLocationPin) {
      _pickedLocation = _config.initialLocation ?? _config.initialCenter;
    }
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = context.read<SearchStateService>();
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      if (mounted) {
        setState(() {
          _isSatelliteView = _searchStateServiceRef!.isSatellite;
        });
      }
    });
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;
    setState(() => _isSatelliteView = searchState.isSatellite);
  }

  Future<void> _loadMarkerIcons() async {
    try {
      const browsePinHeight = MarkerIconUtils.mapPinBrowseLogicalHeight;
      final results = await Future.wait([
        MarkerIconUtils.loadMapPinPng(
          MarkerIconUtils.mapPinNormalAsset,
          fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
          logicalHeight: browsePinHeight,
        ),
        MarkerIconUtils.loadMapPinPng(
          MarkerIconUtils.mapPinNormalSelectedAsset,
          fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
          logicalHeight: browsePinHeight,
        ),
        MarkerIconUtils.loadEventMapPin(logicalHeight: browsePinHeight),
        MarkerIconUtils.loadEventSelectedMapPin(logicalHeight: browsePinHeight),
        if (_config.includesLocationPin)
          MarkerIconUtils.loadNormalSelectedMapPin()
        else
          Future.value(BitmapDescriptor.defaultMarker),
      ]);
      if (mounted) {
        setState(() {
          _spotDefaultIcon = results[0];
          _spotSelectedIcon = results[1];
          _eventIcon = results[2];
          _eventSelectedIcon = results[3];
          if (_config.includesLocationPin) {
            _pickedLocationPinIcon = results[4];
            _markers = _rebuildMarkers();
          }
        });
      }
    } catch (_) {
      // Ignore icon load errors.
    }
  }

  void _releaseMapController() {
    _cameraDebounce?.cancel();
    _cameraDebounce = null;
    _mapController = null;
  }

  void _closePicker([ExploreEntityPickerResult? result]) {
    if (!mounted) return;
    _releaseMapController();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _releaseMapController();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isSpotExcluded(Spot spot) {
    final id = spot.id;
    if (id == null) return true;
    if (_config.excludeSpotIds.contains(id)) return true;
    if (!_config.allowExternalSources && spot.duplicateOf != null) {
      return true;
    }
    return false;
  }

  List<Spot> get _visibleSpots =>
      _loadedSpots.where((spot) => !_isSpotExcluded(spot)).toList();

  Future<void> _loadMapDataForCurrentView() async {
    if (!_config.includesSpots && !_config.includesEvents) return;
    if (_mapController == null || !mounted) return;

    setState(() => _isLoadingMapData = true);

    try {
      final bounds = await _mapController!.getVisibleRegion();
      final minLat = bounds.southwest.latitude;
      final maxLat = bounds.northeast.latitude;
      final minLng = bounds.southwest.longitude;
      final maxLng = bounds.northeast.longitude;

      final spotService = context.read<SpotService>();
      final futures = <Future<dynamic>>[];

      if (_config.includesSpots) {
        futures.add(
          spotService.getTopRankedSpotsInBounds(
            minLat,
            maxLat,
            minLng,
            maxLng,
            limit: 100,
            filterArea: 'amenities',
            spotSource: _config.allowExternalSources ? null : '',
          ),
        );
      } else {
        futures.add(Future.value(<String, dynamic>{'spots': <Spot>[]}));
      }

      if (_config.includesEvents) {
        futures.add(
          context.read<EventMapService>().getEventsInBounds(
            minLat,
            maxLat,
            minLng,
            maxLng,
            limit: 100,
          ),
        );
      }

      final results = await Future.wait(futures);

      if (!mounted) return;

      if (_config.includesSpots) {
        final ranked = results[0] as Map<String, dynamic>;
        _loadedSpots = (ranked['spots'] as List<Spot>?) ?? <Spot>[];
      } else {
        _loadedSpots = [];
      }

      if (_config.includesEvents) {
        final eventsIndex = _config.includesSpots ? 1 : 0;
        final eventsResult = results[eventsIndex] as EventsInBoundsResult;
        _loadedEventPins = dedupePinsByEventId(eventsResult.pins);
      } else {
        _loadedEventPins = [];
      }

      setState(() => _markers = _rebuildMarkers());
    } catch (e) {
      debugPrint('ExploreEntityPicker load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMapData = false);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _lastKnownZoom = position.zoom;
    if (!_config.includesSpots && !_config.includesEvents) return;
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(seconds: 1), () {
      if (mounted) _loadMapDataForCurrentView();
    });
  }

  Set<Marker> _rebuildMarkers() {
    final markers = <Marker>{};

    if (_config.includesLocationPin && _pickedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('picked'),
          position: _pickedLocation!,
          icon: _pickedLocationPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          draggable: true,
          onDragEnd: (LatLng position) {
            setState(() {
              _pickedLocation = position;
            });
          },
        ),
      );
      return markers;
    }

    final visibleSpotIds = _visibleSpots
        .map((s) => s.id)
        .whereType<String>()
        .toSet();

    final spotEntries = MarkerIconUtils.sortByLatitudeNorthFirst(
      _visibleSpots,
      (spot) => spot.latitude,
    );

    for (var i = 0; i < spotEntries.length; i++) {
      final spot = spotEntries[i];
      final isPreviewSelected = _previewSpot?.id != null
          ? _previewSpot!.id == spot.id
          : _previewSpot?.name == spot.name;

      final icon = isPreviewSelected
          ? (_spotSelectedIcon ?? BitmapDescriptor.defaultMarker)
          : (_spotDefaultIcon ?? BitmapDescriptor.defaultMarker);

      markers.add(
        Marker(
          markerId: MarkerId('spot_${spot.id ?? spot.name}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: isPreviewSelected ? _selectedMarkerZBase + i : i,
          onTap: () {
            setState(() {
              _previewSpot = spot;
              _previewEventPin = null;
              _markers = _rebuildMarkers();
            });
          },
        ),
      );
    }

    if (_config.includesEvents) {
      final eventEntries = MarkerIconUtils.sortByLatitudeNorthFirst(
        _loadedEventPins.where((pin) {
          if (_config.excludeEventIds.contains(pin.eventId)) return false;
          if (pin.kind == EventMapPinKind.spot &&
              pin.spotId != null &&
              visibleSpotIds.contains(pin.spotId)) {
            return false;
          }
          return true;
        }),
        (pin) => pin.latitude,
      );

      for (var i = 0; i < eventEntries.length; i++) {
        final pin = eventEntries[i];
        final isPreviewSelected = _previewEventPin?.id == pin.id;

        final icon = isPreviewSelected
            ? (_eventSelectedIcon ?? _eventIcon ?? BitmapDescriptor.defaultMarker)
            : (_eventIcon ?? BitmapDescriptor.defaultMarker);

        markers.add(
          Marker(
            markerId: MarkerId('event_${pin.id}'),
            position: LatLng(pin.latitude, pin.longitude),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: isPreviewSelected ? _selectedMarkerZBase + i : i,
            onTap: () {
              setState(() {
                _previewEventPin = pin;
                _previewSpot = null;
                _markers = _rebuildMarkers();
              });
            },
          ),
        );
      }
    }

    return markers;
  }

  Future<LatLng?> _mapCenter() async {
    if (_mapController == null) return null;
    try {
      final bounds = await _mapController!.getVisibleRegion();
      return LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _buildAutocompleteOptions(
    String query,
  ) async {
    _placesSessionToken ??= const Uuid().v4();
    return buildExploreAutocompleteOptions(
      query: query,
      config: _config,
      geocoding: context.read<GeocodingService>(),
      spotService: context.read<SpotService>(),
      eventsService: context.read<AdminEventsService>(),
      placesSessionToken: _placesSessionToken,
      mapCenter: await _mapCenter(),
    );
  }

  Future<void> _selectPlaceSuggestion(Map<String, dynamic> suggestion) async {
    setState(() => _isSearchingLocation = true);
    try {
      final geocoding = context.read<GeocodingService>();
      final placeId = suggestion['placeId'] as String?;
      if (placeId == null || _mapController == null) return;

      final details = await geocoding.placeDetails(
        placeId: placeId,
        sessionToken: _placesSessionToken,
      );
      _placesSessionToken = null;
      if (details == null) return;

      final lat = (details['latitude'] as num?)?.toDouble();
      final lng = (details['longitude'] as num?)?.toDouble();
      final formatted =
          details['formattedAddress'] as String? ??
          details['formatted_address'] as String? ??
          suggestion['description'] as String? ??
          '';

      if (lat != null && lng != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, lng),
              zoom: zoomLevelForPlaceDetails(details),
            ),
          ),
        );
      }

      setState(() {
        _searchController.text = formatted;
        _previewSpot = null;
        _previewEventPin = null;
      });
      _searchFocusNode.unfocus();
      await _loadMapDataForCurrentView();
    } catch (e) {
      debugPrint('ExploreEntityPicker place select error: $e');
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<void> _locateSpot(Spot spot) async {
    if (_mapController != null) {
      const desiredZoom = 15.0;
      final targetZoom =
          _lastKnownZoom < desiredZoom ? desiredZoom : _lastKnownZoom;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(spot.latitude, spot.longitude)),
      );
      if (_lastKnownZoom < targetZoom) {
        await _mapController!.animateCamera(CameraUpdate.zoomTo(targetZoom));
      }
    }
    setState(() {
      _previewSpot = spot;
      _previewEventPin = null;
      _markers = _rebuildMarkers();
    });
    if (spot.id != null) {
      context.read<SpotService>().getSpotById(spot.id!).then((fullSpot) {
        if (fullSpot != null && mounted && _previewSpot?.id == spot.id) {
          setState(() => _previewSpot = fullSpot);
        }
      });
    }
  }

  Future<void> _locateEventById(String eventId) async {
    EventMapPin? loadedPin;
    for (final pin in _loadedEventPins) {
      if (pin.eventId == eventId) {
        loadedPin = pin;
        break;
      }
    }

    if (loadedPin != null) {
      await _focusEventPin(loadedPin);
      return;
    }

    final event = await context.read<AdminEventsService>().getEventById(eventId);
    if (event == null || !mounted) return;

    final pin = await context.read<EventMapService>().resolvePinForLocate(event);
    if (pin == null || !mounted) return;

    await _focusEventPin(pin);
  }

  Future<void> _focusEventPin(EventMapPin pin) async {
    if (_mapController != null) {
      const desiredZoom = 15.0;
      final targetZoom =
          _lastKnownZoom < desiredZoom ? desiredZoom : _lastKnownZoom;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
      );
      if (_lastKnownZoom < targetZoom) {
        await _mapController!.animateCamera(CameraUpdate.zoomTo(targetZoom));
      }
    }
    setState(() {
      _previewEventPin = pin;
      _previewSpot = null;
      _markers = _rebuildMarkers();
    });
  }

  Future<void> _selectAutocompleteOption(Map<String, dynamic> option) async {
    final optionType = option['optionType'] as String? ?? 'place';
    if (optionType == 'spot') {
      final spot = option['spot'];
      if (spot is Spot) {
        _searchController.text = spot.name;
        _searchFocusNode.unfocus();
        await _locateSpot(spot);
      }
      return;
    }
    if (optionType == 'event') {
      final eventId = option['eventId'] as String?;
      if (eventId != null) {
        _searchController.text = option['description'] as String? ?? '';
        _searchFocusNode.unfocus();
        await _locateEventById(eventId);
      }
      return;
    }
    await _selectPlaceSuggestion(option);
  }

  void _dismissPreview() {
    setState(() {
      _previewSpot = null;
      _previewEventPin = null;
      _markers = _rebuildMarkers();
    });
  }

  void _onMapTap(LatLng position) {
    if (!_config.includesLocationPin) return;
    setState(() {
      _pickedLocation = position;
      _previewSpot = null;
      _previewEventPin = null;
      _markers = _rebuildMarkers();
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    final position =
        await LocationPermissionUtils.getCurrentPositionWithPermission(
          context: context,
          showErrorMessages: true,
          accuracy: LocationAccuracy.high,
        );

    if (mounted && position != null) {
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        if (_config.includesLocationPin) {
          _pickedLocation = location;
          _markers = _rebuildMarkers();
        }
      });
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: location, zoom: 16),
          ),
        );
      }
    }

    if (mounted) setState(() => _isGettingLocation = false);
  }

  void _confirmSpot(Spot spot) {
    if (spot.id == null) return;
    _closePicker(ExploreEntityPickerResult.spot(spot));
  }

  Future<void> _confirmEvent(EventMapPin pin) async {
    setState(() => _isConfirming = true);
    try {
      final event = await context.read<AdminEventsService>().getEventById(
        pin.eventId,
      );
      if (event == null || !mounted) return;
      _closePicker(ExploreEntityPickerResult.event(event));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _confirmLocation() {
    final location = _pickedLocation;
    if (location == null) return;
    _closePicker(ExploreEntityPickerResult.location(location));
  }

  String _title(AppLocalizations l10n) {
    return switch (_config.mode) {
      ExploreEntityPickerMode.locationOnly => l10n.explorePickerTitleLocation,
      ExploreEntityPickerMode.spotsOnly => l10n.explorePickerTitleSpots,
      ExploreEntityPickerMode.eventsOnly => l10n.explorePickerTitleEvents,
      ExploreEntityPickerMode.spotsAndEvents =>
        l10n.explorePickerTitleSpotsAndEvents,
    };
  }

  String _searchHint(AppLocalizations l10n) {
    return switch (_config.mode) {
      ExploreEntityPickerMode.locationOnly =>
        l10n.explorePickerSearchHintLocation,
      ExploreEntityPickerMode.eventsOnly => l10n.explorePickerSearchHintEvents,
      ExploreEntityPickerMode.spotsOnly ||
      ExploreEntityPickerMode.spotsAndEvents => l10n.exploreSearchHint,
    };
  }

  String? _usageTipText(AppLocalizations l10n) {
    return switch (_config.usageTip) {
      LocationPickerUsageTip.addSpot =>
        MobileDetectionService.isMobileDevice
            ? l10n.addSpotTipLongPressMobile
            : l10n.addSpotTipRightClickDesktop,
      LocationPickerUsageTip.addEvent =>
        MobileDetectionService.isMobileDevice
            ? l10n.addEventTipLongPressMobile
            : l10n.addEventTipRightClickDesktop,
      null => null,
    };
  }

  LatLng get _initialCameraTarget {
    return _config.initialLocation ??
        _config.initialCenter ??
        const LatLng(
          AppConfig.defaultMapCenterLat,
          AppConfig.defaultMapCenterLng,
        );
  }

  double get _initialZoom {
    if (_config.initialLocation != null || _config.initialCenter != null) {
      return 16;
    }
    return _config.includesLocationPin ? 10 : 14;
  }

  double _fabRightOffset(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth > _kMaxContentWidth
        ? (screenWidth - _kMaxContentWidth) / 2 + 16
        : 16;
  }

  double _previewPanelWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth >= 600) return _kPreviewPanelMaxWidth;
    return screenWidth - 32;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final usageTip = _usageTipText(l10n);
    final showEntityPreview =
        _previewSpot != null || _previewEventPin != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAppBar(l10n, theme),
                if (usageTip != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      usageTip,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _initialCameraTarget,
                          zoom: _initialZoom,
                        ),
                        mapType: _isSatelliteView
                            ? MapType.hybrid
                            : MapType.normal,
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        liteModeEnabled: kIsWeb,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (_config.includesSpots ||
                              _config.includesEvents) {
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (mounted) _loadMapDataForCurrentView();
                              },
                            );
                          } else if (_config.includesLocationPin &&
                              _pickedLocation != null) {
                            setState(() => _markers = _rebuildMarkers());
                          }
                        },
                        onCameraMove: _onCameraMove,
                        onTap: _onMapTap,
                      ),
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: _buildSearchField(l10n, theme),
                      ),
                      if (_isLoadingMapData || _isSearchingLocation)
                        Positioned(
                          top: 72,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: PointerInterceptor(
                              child: Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.explorePickerLoading,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!showEntityPreview) ...[
                        _buildSatelliteFab(l10n),
                        _buildLocationFab(l10n),
                      ],
                      if (_config.includesLocationPin && !showEntityPreview)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: PointerInterceptor(
                              child: FloatingActionButton.extended(
                                onPressed: _pickedLocation == null
                                    ? null
                                    : _confirmLocation,
                                icon: const Icon(Icons.check),
                                label: Text(l10n.addSpotUseThisLocation),
                              ),
                            ),
                          ),
                        ),
                      if (_previewSpot != null)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: _buildSpotPreview(l10n),
                        ),
                      if (_previewEventPin != null)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: _buildEventPreview(l10n),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
            onPressed: () => _closePicker(),
          ),
          Expanded(
            child: Text(
              _title(l10n),
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatelliteFab(AppLocalizations l10n) {
    return Positioned(
      bottom: 88,
      right: _fabRightOffset(context),
      child: PointerInterceptor(
        child: FloatingActionButton(
          onPressed: () {
            setState(() => _isSatelliteView = !_isSatelliteView);
            _searchStateServiceRef?.setSatellite(_isSatelliteView);
          },
          heroTag: 'pickerMapTypeToggleFab',
          mini: true,
          tooltip: _isSatelliteView
              ? l10n.exploreSwitchToMap
              : l10n.exploreSwitchToSatellite,
          child: Icon(_isSatelliteView ? Icons.map : Icons.terrain),
        ),
      ),
    );
  }

  Widget _buildLocationFab(AppLocalizations l10n) {
    return Positioned(
      bottom: 24,
      right: _fabRightOffset(context),
      child: PointerInterceptor(
        child: FloatingActionButton(
          onPressed: _getCurrentLocation,
          heroTag: 'pickerCurrentLocationFab',
          mini: true,
          tooltip: l10n.exploreCenterOnMyLocation,
          child: _isGettingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n, ThemeData theme) {
    return PointerInterceptor(
      child: RawAutocomplete<Map<String, dynamic>>(
        textEditingController: _searchController,
        focusNode: _searchFocusNode,
        optionsBuilder: (textEditingValue) async {
          return _buildAutocompleteOptions(textEditingValue.text);
        },
        onSelected: _selectAutocompleteOption,
        displayStringForOption: (option) =>
            option['description'] as String? ?? '',
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return SearchBar(
            controller: controller,
            focusNode: focusNode,
            hintText: _searchHint(l10n),
            leading: const Icon(Icons.search),
            trailing: controller.text.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        _dismissPreview();
                      },
                    ),
                  ]
                : null,
            onSubmitted: (_) {},
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topCenter,
            child: PointerInterceptor(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 560,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final optionType =
                          option['optionType'] as String? ?? 'place';
                      final description =
                          option['description'] as String? ?? '';
                      final secondary = option['secondary'] as String?;
                      final leadingIcon = switch (optionType) {
                        'spot' => Icons.place_outlined,
                        'event' => Icons.event_outlined,
                        _ => Icons.public_outlined,
                      };
                      return ListTile(
                        leading: Icon(leadingIcon),
                        dense: true,
                        title: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: secondary != null
                            ? Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpotPreview(AppLocalizations l10n) {
    final spot = _previewSpot!;

    return PointerInterceptor(
      child: SizedBox(
        width: _previewPanelWidth(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpotCard(
              spot: spot,
              variant: SpotCardVariant.overlay,
              maxWidth: _kPreviewPanelMaxWidth,
              showCheckInPresence: false,
              onClose: _dismissPreview,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: spot.id == null ? null : () => _confirmSpot(spot),
              child: Text(l10n.explorePickerConfirmSelect),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPreview(AppLocalizations l10n) {
    final pin = _previewEventPin!;

    return PointerInterceptor(
      child: SizedBox(
        width: _previewPanelWidth(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EventCard(
              pin: pin,
              variant: EventCardVariant.overlay,
              maxWidth: _kPreviewPanelMaxWidth,
              onClose: _dismissPreview,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isConfirming ? null : () => _confirmEvent(pin),
              child: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.explorePickerConfirmSelect),
            ),
          ],
        ),
      ),
    );
  }
}
