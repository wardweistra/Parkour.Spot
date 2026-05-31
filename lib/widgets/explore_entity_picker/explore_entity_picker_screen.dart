import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_map_pin.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/event_map_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/spot_service.dart';
import '../../utils/explore_events_utils.dart';
import '../../utils/explore_search_autocomplete.dart';
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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  GoogleMapController? _mapController;
  Timer? _cameraDebounce;
  String? _placesSessionToken;
  double _lastKnownZoom = 14;

  List<Spot> _loadedSpots = [];
  List<EventMapPin> _loadedEventPins = [];
  Set<Marker> _markers = {};

  Spot? _previewSpot;
  EventMapPin? _previewEventPin;

  final List<Spot> _selectedSpots = [];
  final List<ParkourEvent> _selectedEvents = [];

  bool _isLoadingMapData = false;
  bool _isSearchingLocation = false;
  bool _isConfirming = false;

  BitmapDescriptor? _spotDefaultIcon;
  BitmapDescriptor? _spotSelectedIcon;
  BitmapDescriptor? _eventIcon;
  BitmapDescriptor? _eventSelectedIcon;

  ExploreEntityPickerConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _selectedSpots.addAll(_config.preselectedSpots);
    _loadMissingPreselectedSpots();
    _loadMarkerIcons();
  }

  Future<void> _loadMissingPreselectedSpots() async {
    final knownIds = _selectedSpots.map((s) => s.id).whereType<String>().toSet();
    final missingIds = _config.preselectedSpotIds.difference(knownIds);
    if (missingIds.isEmpty) return;

    final spotService = context.read<SpotService>();
    for (final id in missingIds) {
      final spot = await spotService.getSpotById(id);
      if (spot != null && mounted) {
        setState(() {
          if (!_selectedSpots.any((s) => s.id == spot.id)) {
            _selectedSpots.add(spot);
          }
        });
      }
    }
  }

  Future<void> _loadMarkerIcons() async {
    try {
      const browsePinHeight = MarkerIconUtils.mapPinBrowseLogicalHeight;
      final normalPin = await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinNormalAsset,
        fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final normalSelectedPin = await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinNormalSelectedAsset,
        fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final eventPin = await MarkerIconUtils.loadEventMapPin(
        logicalHeight: browsePinHeight,
      );
      final eventSelectedPin = await MarkerIconUtils.loadEventSelectedMapPin(
        logicalHeight: browsePinHeight,
      );
      if (mounted) {
        setState(() {
          _spotDefaultIcon = normalPin;
          _spotSelectedIcon = normalSelectedPin;
          _eventIcon = eventPin;
          _eventSelectedIcon = eventSelectedPin;
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
    _releaseMapController();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isSpotSelected(Spot spot) {
    final id = spot.id;
    if (id == null) return false;
    return _selectedSpots.any((s) => s.id == id);
  }

  bool _isEventSelected(EventMapPin pin) {
    return _selectedEvents.any((e) => e.id == pin.eventId);
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
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(seconds: 1), () {
      if (mounted) _loadMapDataForCurrentView();
    });
  }

  Set<Marker> _rebuildMarkers() {
    final markers = <Marker>{};
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
      final isChosen = _isSpotSelected(spot);
      final isSelected = isPreviewSelected || isChosen;

      final icon = isSelected
          ? (_spotSelectedIcon ?? BitmapDescriptor.defaultMarker)
          : (_spotDefaultIcon ?? BitmapDescriptor.defaultMarker);

      markers.add(
        Marker(
          markerId: MarkerId('spot_${spot.id ?? spot.name}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: isSelected ? _selectedMarkerZBase + i : i,
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
        final isChosen = _isEventSelected(pin);
        final isSelected = isPreviewSelected || isChosen;

        final icon = isSelected
            ? (_eventSelectedIcon ?? _eventIcon ?? BitmapDescriptor.defaultMarker)
            : (_eventIcon ?? BitmapDescriptor.defaultMarker);

        markers.add(
          Marker(
            markerId: MarkerId('event_${pin.id}'),
            position: LatLng(pin.latitude, pin.longitude),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: isSelected ? _selectedMarkerZBase + i : i,
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

  Future<List<Map<String, dynamic>>> _buildAutocompleteOptions(String query) async {
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
          setState(() {
            _previewSpot = fullSpot;
          });
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
    if (event?.latitude == null || event?.longitude == null || !mounted) {
      return;
    }
    await _focusEventPin(EventMapPin.fromParkourEvent(event!));
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

  Future<void> _confirmSpot(Spot spot) async {
    if (spot.id == null || _isSpotSelected(spot)) return;

    if (!_config.allowMultiple) {
      _closePicker(ExploreEntityPickerResult.spots([spot]));
      return;
    }

    setState(() {
      _selectedSpots.add(spot);
      _previewSpot = null;
      _markers = _rebuildMarkers();
    });
  }

  Future<void> _confirmEvent(EventMapPin pin) async {
    if (_isEventSelected(pin)) return;
    setState(() => _isConfirming = true);
    try {
      final event = await context.read<AdminEventsService>().getEventById(
        pin.eventId,
      );
      if (event == null || !mounted) return;

      if (!_config.allowMultiple) {
        _closePicker(ExploreEntityPickerResult.events([event]));
        return;
      }

      setState(() {
        _selectedEvents.add(event);
        _previewEventPin = null;
        _markers = _rebuildMarkers();
      });
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _finishMultiSelect() {
    if (_config.includesSpots && !_config.includesEvents) {
      _closePicker(
        ExploreEntityPickerResult.spots(List<Spot>.from(_selectedSpots)),
      );
      return;
    }
    if (_config.includesEvents && !_config.includesSpots) {
      _closePicker(
        ExploreEntityPickerResult.events(List<ParkourEvent>.from(_selectedEvents)),
      );
      return;
    }
    // Mixed mode: return whichever has selections (future use).
    if (_selectedSpots.isNotEmpty) {
      _closePicker(
        ExploreEntityPickerResult.spots(List<Spot>.from(_selectedSpots)),
      );
    } else if (_selectedEvents.isNotEmpty) {
      _closePicker(
        ExploreEntityPickerResult.events(List<ParkourEvent>.from(_selectedEvents)),
      );
    } else {
      _closePicker();
    }
  }

  String _title(AppLocalizations l10n) {
    return switch (_config.mode) {
      ExploreEntityPickerMode.spotsOnly => l10n.explorePickerTitleSpots,
      ExploreEntityPickerMode.eventsOnly => l10n.explorePickerTitleEvents,
      ExploreEntityPickerMode.spotsAndEvents =>
        l10n.explorePickerTitleSpotsAndEvents,
    };
  }

  String _searchHint(AppLocalizations l10n) {
    return switch (_config.mode) {
      ExploreEntityPickerMode.eventsOnly => l10n.explorePickerSearchHintEvents,
      ExploreEntityPickerMode.spotsOnly ||
      ExploreEntityPickerMode.spotsAndEvents => l10n.exploreSearchHint,
    };
  }

  int get _selectionCount {
    if (_config.includesSpots && !_config.includesEvents) {
      return _selectedSpots.length;
    }
    if (_config.includesEvents && !_config.includesSpots) {
      return _selectedEvents.length;
    }
    return _selectedSpots.length + _selectedEvents.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final initialTarget =
        _config.initialCenter ??
        const LatLng(
          AppConfig.defaultMapCenterLat,
          AppConfig.defaultMapCenterLng,
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAppBar(l10n, theme),
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialTarget,
                          zoom: _config.initialCenter != null ? 14 : 10,
                        ),
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: !kIsWeb,
                        liteModeEnabled: kIsWeb,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) _loadMapDataForCurrentView();
                          });
                        },
                        onCameraMove: _onCameraMove,
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
          if (_config.allowMultiple && _selectionCount > 0)
            TextButton(
              onPressed: _finishMultiSelect,
              child: Text(l10n.explorePickerDone(_selectionCount)),
            ),
        ],
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
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 560),
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

  static const double _kPreviewPanelMaxWidth = 400;

  double _previewPanelWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth >= 600) return _kPreviewPanelMaxWidth;
    return screenWidth - 32;
  }

  Widget _buildSpotPreview(AppLocalizations l10n) {
    final spot = _previewSpot!;
    final alreadyAdded = _isSpotSelected(spot);

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
              onPressed: alreadyAdded || spot.id == null
                  ? null
                  : () => _confirmSpot(spot),
              child: Text(
                alreadyAdded
                    ? l10n.explorePickerAlreadyAdded
                    : (_config.allowMultiple
                          ? l10n.explorePickerConfirmAdd
                          : l10n.explorePickerConfirmSelect),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPreview(AppLocalizations l10n) {
    final pin = _previewEventPin!;
    final alreadyAdded = _isEventSelected(pin);

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
              onPressed: alreadyAdded || _isConfirming
                  ? null
                  : () => _confirmEvent(pin),
              child: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      alreadyAdded
                          ? l10n.explorePickerAlreadyAdded
                          : (_config.allowMultiple
                                ? l10n.explorePickerConfirmAdd
                                : l10n.explorePickerConfirmSelect),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
