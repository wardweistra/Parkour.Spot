import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, listEquals;
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../services/event_map_service.dart';
import '../../services/spot_service.dart';
import '../../models/event_map_pin.dart';
import '../../utils/explore_events_utils.dart';
import '../../widgets/explore_event_list_tile.dart';
import '../../widgets/explore_bottom_sheet_header.dart';
import '../../services/sync_source_service.dart';
import '../../services/search_state_service.dart';
import '../../services/url_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/auth_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/user_locations_of_interest_service.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../widgets/spot_card.dart';
import '../../widgets/source_details_dialog.dart';
import '../../config/app_config.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/map_bounds_utils.dart';
import '../../utils/location_permission_utils.dart';
import '../../constants/spot_attributes.dart';
import '../../l10n/app_localizations.dart';

/// Stateful overlay for autocomplete suggestions; manages ScrollController lifecycle.
class _AutocompleteOverlayContent extends StatefulWidget {
  final List<Map<String, dynamic>> optionsList;
  final int? currentSelection;
  final void Function(Map<String, dynamic>) onSelected;

  const _AutocompleteOverlayContent({
    required this.optionsList,
    required this.currentSelection,
    required this.onSelected,
  });

  @override
  State<_AutocompleteOverlayContent> createState() =>
      _AutocompleteOverlayContentState();
}

class _AutocompleteOverlayContentState
    extends State<_AutocompleteOverlayContent> {
  late ScrollController _scrollController;

  /// Last highlight index we scrolled to match. RawAutocomplete defaults highlight to 0; we must
  /// not re-sync scroll on every rebuild or [animateTo(0)] fights manual scrolling (web/desktop).
  int? _lastSyncedHighlightIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _optionsListMeaningfullyChanged(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return true;
    if (newList.isEmpty) return false;
    String descAt(List<Map<String, dynamic>> list, int i) =>
        list[i]['description'] as String? ?? '';
    return descAt(oldList, 0) != descAt(newList, 0) ||
        descAt(oldList, oldList.length - 1) !=
            descAt(newList, newList.length - 1);
  }

  @override
  void didUpdateWidget(_AutocompleteOverlayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_optionsListMeaningfullyChanged(
      oldWidget.optionsList,
      widget.optionsList,
    )) {
      _lastSyncedHighlightIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsList = widget.optionsList;
    final currentSelection = widget.currentSelection;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (currentSelection == null || currentSelection >= optionsList.length) {
        return;
      }
      if (currentSelection == _lastSyncedHighlightIndex) {
        return;
      }
      _lastSyncedHighlightIndex = currentSelection;
      const itemHeight = 48.0;
      final targetOffset = currentSelection * itemHeight;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });

    return Align(
      alignment: Alignment.topLeft,
      child: PointerInterceptor(
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: optionsList.length,
              itemBuilder: (context, index) {
                final option = optionsList[index];
                final optionType = option['optionType'] as String? ?? 'place';
                final isSpotSuggestion = optionType == 'spot';
                final description = option['description'] as String? ?? '';
                final secondary = option['secondary'] as String?;
                final isSelected = currentSelection == index;
                final leadingIcon = isSpotSuggestion
                    ? (isSelected ? Icons.place : Icons.place_outlined)
                    : (isSelected ? Icons.public : Icons.public_outlined);

                return Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        )
                      : null,
                  child: ListTile(
                    leading: Icon(
                      leadingIcon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    dense: true,
                    title: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isSelected
                          ? TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    subtitle: secondary != null
                        ? Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isSelected
                                ? TextStyle(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.8),
                                  )
                                : null,
                          )
                        : null,
                    selected: isSelected,
                    selectedTileColor: Colors.transparent,
                    onTap: () => widget.onSelected(option),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Helper widget to ensure icons render properly on mobile web
class ReliableIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const ReliableIcon({super.key, required this.icon, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    // On mobile web, sometimes Material Icons don't render properly
    // This provides a fallback with better error handling
    if (kIsWeb) {
      // For web, use a more explicit approach to ensure icons load
      return Icon(
        icon,
        size: size,
        color: color,
        // Add explicit font family for web
        textDirection: TextDirection.ltr,
      );
    }

    return Icon(icon, size: size, color: color);
  }
}

class SearchScreen extends StatefulWidget {
  final String? initialLocationQuery;
  final String? initialListId;

  const SearchScreen({
    super.key,
    this.initialLocationQuery,
    this.initialListId,
  });

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isGettingLocation = false;
  bool _isLocationPermissionDenied = false;
  bool _isSatelliteView = false;
  bool _isBottomSheetOpen = false; // Start collapsed by default
  Position? _currentPosition;
  BitmapDescriptor? _userLocationIcon;
  BitmapDescriptor? _spotDefaultIcon;
  BitmapDescriptor? _spotSelectedIcon;
  BitmapDescriptor? _spotHighlightedIcon;
  BitmapDescriptor? _spotSelectedHighlightedIcon;
  BitmapDescriptor? _addSpotPinIcon;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _placesSessionToken;
  TextEditingController?
  _autocompleteController; // Keep reference to autocomplete's controller
  FocusNode? _autocompleteFocusNode; // Focus node for search field
  List<Spot> _visibleSpots = [];
  List<Spot> _loadedSpots = []; // Spots loaded for the current map view
  Set<Marker> _markers = {};
  Spot? _selectedSpot;
  bool _isLoadingSpotsForView =
      false; // Loading state for spots within current view
  bool _isSearchingLocation = false; // Loading state for location search
  int? _totalSpotsInView; // Total unfiltered spots in current bounds
  int? _bestShownCount; // Number of ranked spots returned (up to 100)
  List<EventMapPin> _loadedEventPins = [];
  List<EventMapPin> _visibleEvents = [];
  Map<String, EventMapPin> _eventPinBySpotId = {};
  int? _totalEventPinsInView;
  int? _eventCountInView;
  bool _isLoadingEventsForView = false;
  String _exploreListMode = 'spots';
  BitmapDescriptor? _eventVenueIcon;
  BitmapDescriptor? _eventSpotIcon;
  BitmapDescriptor? _eventSpotSelectedIcon;
  late AnimationController _bottomSheetAnimationController;
  late Animation<double> _bottomSheetAnimation;
  late PageController _imagePageController;
  double _dragStartY = 0.0;
  bool _isDragging = false;
  double _lastKnownZoom = 14.0;
  // Filters
  String? _filterArea; // "amenities" | "source" | null (default = amenities)
  String?
  _selectedSpotSource; // null = all sources, "" = native only, string = specific source ID
  List<String> _spotAccess =
      []; // when amenities: ["public", "restricted", "paid"] for OR query
  bool? _spotFacilitiesCovered; // when amenities: true = "yes"
  bool? _spotFacilitiesLighting; // when amenities: true = "yes"
  bool? _spotFacilitiesWaterTap; // when amenities: true = "yes"
  bool? _spotFacilitiesToilet; // when amenities: true = "yes"
  bool? _spotFacilitiesParking; // when amenities: true = "yes"
  List<String> _goodFor = []; // when amenities: array-contains-any
  List<String> _spotFeatures = []; // when amenities: array-contains-any
  String _attributeFilterMode = 'goodFor'; // "goodFor" | "spotFeatures"
  bool _showFiltersDialog = false; // Controls filters dialog visibility
  bool _hasRequestedSyncSourcesForFilters = false;
  SpotService? _spotServiceRef; // To attach a listener for spot updates
  SyncSourceService?
  _syncSourceServiceRef; // To attach a listener for sync source updates
  SearchStateService?
  _searchStateServiceRef; // To attach a listener for search state updates
  LatLng? _longPressedLocation; // Location from long press on map
  Timer? _longPressTimer; // Timer for detecting long press on mobile web
  Offset? _longPressStartPosition; // Starting position for long press detection
  bool _longPressHandled =
      false; // Flag to track if long press was successfully handled
  String? _spotIdToLocate; // Spot ID to locate from query parameter
  Timer? _locationPollingTimer; // Timer for polling user location periodically
  // Spot list highlighting
  String? _selectedListId; // Currently selected spot list ID
  String? _selectedListName; // Name of the selected spot list
  SpotList? _selectedList; // Full spot list object for preview
  bool _showListPreview = false; // Whether to show the list preview card
  Set<String> _highlightedSpotIds = {}; // Spot IDs from selected list
  DateTime? _lastAutocompleteSpotSelection; // Guard against mobile tap-through
  bool _hasSetInitialAutocompleteQuery = false;
  bool _hasAutocompleteOptions =
      false; // True when options overlay has suggestions (for Enter-key behavior)

  void _onSpotsChanged() {
    if (mounted) {
      _updateVisibleSpots();
    }
  }

  void _onSyncSourcesChanged() {
    // Sync sources changed - no action needed for single source selection
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;

    // Update local state from SearchStateService
    final newFilterArea = searchState.filterArea;
    final newSelectedSpotSource = searchState.selectedSpotSource;
    final newSpotAccess = List<String>.from(searchState.spotAccess);
    final newSpotFacilitiesCovered = searchState.spotFacilitiesCovered;
    final newSpotFacilitiesLighting = searchState.spotFacilitiesLighting;
    final newSpotFacilitiesWaterTap = searchState.spotFacilitiesWaterTap;
    final newSpotFacilitiesToilet = searchState.spotFacilitiesToilet;
    final newSpotFacilitiesParking = searchState.spotFacilitiesParking;
    final newGoodFor = List<String>.from(searchState.goodFor);
    final newSpotFeatures = List<String>.from(searchState.spotFeatures);
    final newAttributeFilterMode = searchState.attributeFilterMode;
    final newIsSatelliteView = searchState.isSatellite;
    final newSelectedListId = searchState.selectedListId;

    final filterChanged =
        _filterArea != newFilterArea ||
        _selectedSpotSource != newSelectedSpotSource ||
        !listEquals(_spotAccess, newSpotAccess) ||
        _spotFacilitiesCovered != newSpotFacilitiesCovered ||
        _spotFacilitiesLighting != newSpotFacilitiesLighting ||
        _spotFacilitiesWaterTap != newSpotFacilitiesWaterTap ||
        _spotFacilitiesToilet != newSpotFacilitiesToilet ||
        _spotFacilitiesParking != newSpotFacilitiesParking ||
        !listEquals(_goodFor, newGoodFor) ||
        !listEquals(_spotFeatures, newSpotFeatures) ||
        _attributeFilterMode != newAttributeFilterMode;
    final listIdChanged = _selectedListId != newSelectedListId;

    setState(() {
      _isSatelliteView = newIsSatelliteView;
      _filterArea = newFilterArea;
      _selectedSpotSource = newSelectedSpotSource;
      _spotAccess = newSpotAccess;
      _spotFacilitiesCovered = newSpotFacilitiesCovered;
      _spotFacilitiesLighting = newSpotFacilitiesLighting;
      _spotFacilitiesWaterTap = newSpotFacilitiesWaterTap;
      _spotFacilitiesToilet = newSpotFacilitiesToilet;
      _spotFacilitiesParking = newSpotFacilitiesParking;
      _goodFor = newGoodFor;
      _spotFeatures = newSpotFeatures;
      _attributeFilterMode = newAttributeFilterMode;
      _selectedListId = newSelectedListId;
    });

    if (listIdChanged) {
      if (newSelectedListId != null) {
        _loadSpotList(newSelectedListId);
      } else {
        setState(() {
          _selectedList = null;
          _selectedListName = null;
          _showListPreview = false;
          _highlightedSpotIds.clear();
          _markers = _rebuildMarkers();
        });
      }
    }

    if (filterChanged && _mapController != null) {
      _loadMapDataForCurrentView();
    } else if (filterChanged) {
      _updateVisibleSpots();
    }
  }

  bool _hasActiveFilters() {
    final searchState = _searchStateServiceRef;
    // Match _buildFilters / spot queries: null means default amenities, not "source".
    if ((_filterArea ?? 'amenities') == 'amenities') {
      return _spotAccess.isNotEmpty ||
          _spotFacilitiesCovered == true ||
          _spotFacilitiesLighting == true ||
          _spotFacilitiesWaterTap == true ||
          _spotFacilitiesToilet == true ||
          _spotFacilitiesParking == true ||
          _goodFor.isNotEmpty ||
          _spotFeatures.isNotEmpty;
    }
    final hasFolderFilter =
        _selectedSpotSource != null &&
        _selectedSpotSource!.isNotEmpty &&
        searchState != null &&
        searchState
            .getSelectedFoldersForSource(_selectedSpotSource!)
            .isNotEmpty;
    return _selectedSpotSource != null || hasFolderFilter;
  }

  @override
  void initState() {
    super.initState();
    // Removed automatic location fetching - now user-controlled
    _searchController.addListener(_onSearchChanged);

    // Check permission status on initialization to show correct icon
    _checkLocationPermission();

    // Set initial location query if provided (displayed via Autocomplete fieldViewBuilder)
    if (widget.initialLocationQuery != null &&
        widget.initialLocationQuery!.isNotEmpty) {
      _searchQuery = widget.initialLocationQuery!;
    }

    // Set initial list ID - prioritize URL parameter, then fall back to stored value
    // Will be set from SearchStateService in post-frame callback if not provided via URL

    _loadUserLocationIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSpotIcons();
      }
    });

    // Initialize bottom sheet animation
    _bottomSheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation =
        Tween<double>(
          begin: 0.09, // Very compact when collapsed - minimal footprint
          end:
              0.75, // Less expanded - still good for browsing but leaves more map visible
        ).animate(
          CurvedAnimation(
            parent: _bottomSheetAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // Initialize image page controller
    _imagePageController = PageController();

    // Initialize provider references and listeners.
    // Safe to call with listen: false in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Listen to SearchStateService changes to update filters when storage loads
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);

      // Initial state load (will be updated when storage finishes loading via listener)
      // Prioritize URL parameter over stored value
      final listIdFromUrl = widget.initialListId;
      final listIdFromStorage = _searchStateServiceRef!.selectedListId;
      final initialListId = listIdFromUrl ?? listIdFromStorage;

      // If URL has a listId, save it to storage
      if (listIdFromUrl != null && listIdFromUrl != listIdFromStorage) {
        _searchStateServiceRef!.setSelectedListId(listIdFromUrl);
      }

      setState(() {
        _isSatelliteView = _searchStateServiceRef!.isSatellite;
        _filterArea = _searchStateServiceRef!.filterArea;
        _selectedSpotSource = _searchStateServiceRef!.selectedSpotSource;
        _spotAccess = List<String>.from(_searchStateServiceRef!.spotAccess);
        _spotFacilitiesCovered = _searchStateServiceRef!.spotFacilitiesCovered;
        _spotFacilitiesLighting =
            _searchStateServiceRef!.spotFacilitiesLighting;
        _spotFacilitiesWaterTap =
            _searchStateServiceRef!.spotFacilitiesWaterTap;
        _spotFacilitiesToilet = _searchStateServiceRef!.spotFacilitiesToilet;
        _spotFacilitiesParking = _searchStateServiceRef!.spotFacilitiesParking;
        _goodFor = List<String>.from(_searchStateServiceRef!.goodFor);
        _spotFeatures = List<String>.from(_searchStateServiceRef!.spotFeatures);
        _attributeFilterMode = _searchStateServiceRef!.attributeFilterMode;
        _selectedListId = initialListId;
      });

      // If we have a list ID (from URL or storage), load it
      if (initialListId != null) {
        _loadSpotList(initialListId);
        // If listId came from URL (not storage), we'll open the preview card
        // after the map is ready (handled in onMapCreated)
      }

      // Listen to SpotService changes to refresh visible spots when data updates
      _spotServiceRef = Provider.of<SpotService>(context, listen: false);
      _spotServiceRef!.addListener(_onSpotsChanged);

      // Listen to SyncSourceService changes to update selected sources
      _syncSourceServiceRef = Provider.of<SyncSourceService>(
        context,
        listen: false,
      );
      _syncSourceServiceRef!.addListener(_onSyncSourcesChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for locateSpotId query parameter (only if not already set)
    if (_spotIdToLocate == null) {
      try {
        final routerState = GoRouterState.of(context);
        final locateSpotId = routerState.uri.queryParameters['locateSpotId'];
        if (locateSpotId != null && locateSpotId.isNotEmpty) {
          _spotIdToLocate = locateSpotId;
        }
      } catch (e) {
        // Ignore errors when accessing router state
      }
    }
  }

  /// Called when the map tab becomes visible. Processes locateSpotId/listId from
  /// the URL and refreshes map tiles (fixes "one tile" issue when map was built off-screen).
  void onMapTabActivated() {
    if (!mounted) return;

    String? locateSpotId;
    String? listIdFromUrl;
    try {
      final state = GoRouterState.of(context);
      locateSpotId = state.uri.queryParameters['locateSpotId'];
      listIdFromUrl = state.uri.queryParameters['listId'];
    } catch (_) {}

    final listId = listIdFromUrl ?? widget.initialListId;
    final hasFocusIntent =
        (locateSpotId != null && locateSpotId.isNotEmpty) ||
        (listId != null && listId.isNotEmpty);

    // Zoom nudge forces tile refresh when map was built off-screen. Skip when
    // we have list/locate - the subsequent camera move will achieve the same.
    if (_mapController != null && !hasFocusIntent) {
      _mapController!.getZoomLevel().then((zoom) async {
        if (!mounted || _mapController == null) return;
        await _mapController!.animateCamera(CameraUpdate.zoomTo(zoom + 0.01));
        if (mounted && _mapController != null) {
          await _mapController!.animateCamera(CameraUpdate.zoomTo(zoom));
        }
      });
    }

    if (listId != null && listId.isNotEmpty) {
      _searchStateServiceRef?.setSelectedListId(listId);
      setState(() => _selectedListId = listId);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _mapController != null) {
          _openSpotListPreview(listId);
        }
      });
    }

    if (locateSpotId != null && locateSpotId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _locateSpotById(locateSpotId!);
      });
    }
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    _longPressTimer?.cancel();
    _locationPollingTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bottomSheetAnimationController.dispose();
    _imagePageController.dispose();
    // Remove listeners
    _spotServiceRef?.removeListener(_onSpotsChanged);
    _syncSourceServiceRef?.removeListener(_onSyncSourcesChanged);
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _toggleFiltersDialog() {
    final shouldOpen = !_showFiltersDialog;
    setState(() {
      _showFiltersDialog = shouldOpen;
    });

    // Let the dialog paint first, then load source metadata in the background.
    if (shouldOpen && (_filterArea ?? 'amenities') == 'source') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureSyncSourcesLoaded();
      });
    }
  }

  void _showSourceDetailsDialog(String sourceId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SourceDetailsDialog(sourceId: sourceId),
    );
  }

  void _ensureSyncSourcesLoaded({bool force = false}) {
    final syncService =
        _syncSourceServiceRef ??
        Provider.of<SyncSourceService>(context, listen: false);

    if (syncService.isLoadingSummaries) return;
    if (!force) {
      if (syncService.sourceSummaries.isNotEmpty) return;
      if (_hasRequestedSyncSourcesForFilters &&
          syncService.summariesError == null) {
        return;
      }
    }

    _hasRequestedSyncSourcesForFilters = true;
    unawaited(
      syncService.fetchSyncSourceSummaries(includeInactive: false).whenComplete(
        () {
          if (syncService.summariesError != null) {
            _hasRequestedSyncSourcesForFilters = false;
          }
        },
      ),
    );
  }

  // Removed debounce-based suggestion fetching; Autocomplete.optionsBuilder now fetches live

  double _getZoomLevelForPlace(Map<String, dynamic> details) {
    // Get place types from the place details
    final types = details['types'] as List<dynamic>? ?? [];

    // Country level - zoom out significantly
    if (types.contains('country')) {
      return 6.0;
    }

    // Administrative area level 1 (state/province) - moderate zoom
    if (types.contains('administrative_area_level_1')) {
      return 8.0;
    }

    // Administrative area level 2 (county) - closer zoom
    if (types.contains('administrative_area_level_2')) {
      return 10.0;
    }

    // City level - closer zoom
    if (types.contains('locality') ||
        types.contains('administrative_area_level_3')) {
      return 12.0;
    }

    // Neighborhood level - close zoom
    if (types.contains('sublocality') || types.contains('neighborhood')) {
      return 13.0;
    }

    // Specific places (restaurants, businesses, etc.) - very close zoom
    if (types.contains('establishment') ||
        types.contains('point_of_interest')) {
      return 15.0;
    }

    // Default zoom level for other types
    return 13.5;
  }

  Future<void> _selectPlaceSuggestion(
    Map<String, dynamic> suggestion, {
    bool manageLoadingState = true,
    bool fromInitialQuery = false,
  }) async {
    if (manageLoadingState) {
      setState(() {
        _isSearchingLocation = true;
      });
    }

    try {
      final geocoding = Provider.of<GeocodingService>(context, listen: false);
      final placeId = suggestion['placeId'] as String?;
      if (placeId == null) {
        if (manageLoadingState) {
          setState(() {
            _isSearchingLocation = false;
          });
        }
        return;
      }
      final details = await geocoding.placeDetails(
        placeId: placeId,
        sessionToken: _placesSessionToken,
      );
      // Reset session token after a selection per Google guidelines
      _placesSessionToken = null;
      if (details == null) {
        if (manageLoadingState) {
          setState(() {
            _isSearchingLocation = false;
          });
        }
        return;
      }
      final double? lat = (details['latitude'] as num?)?.toDouble();
      final double? lng = (details['longitude'] as num?)?.toDouble();
      final String? formatted =
          details['formattedAddress'] as String? ??
          details['formatted_address'] as String?;

      if (lat != null && lng != null && _mapController != null) {
        final zoomLevel = _getZoomLevelForPlace(details);
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: zoomLevel),
          ),
        );
      }
      // Update search field - use autocomplete controller if available, otherwise fall back to _searchController
      final controllerToUpdate = _autocompleteController ?? _searchController;
      final newText = formatted ?? (suggestion['description'] as String? ?? '');
      setState(() {
        controllerToUpdate.text = newText;
        controllerToUpdate.selection = TextSelection.fromPosition(
          TextPosition(offset: controllerToUpdate.text.length),
        );
        _searchQuery = newText; // Keep _searchQuery in sync
        // Guard against mobile tap-through: ignore map taps briefly after any autocomplete selection
        _lastAutocompleteSpotSelection = DateTime.now();
        // Only clear loading state if we're managing it
        if (manageLoadingState) {
          _isSearchingLocation = false;
        }
      });
      // Unfocus the text field to collapse autocomplete suggestions
      if (_autocompleteFocusNode != null && _autocompleteFocusNode!.hasFocus) {
        _autocompleteFocusNode!.unfocus();
      }
      // Trigger a refresh of visible spots for new area
      _updateVisibleSpots();
    } catch (e) {
      // Log errors for debugging
      debugPrint('Error selecting place: $e');
      if (manageLoadingState) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
      // No-op: suggestions list is now built live by optionsBuilder
    }
  }

  String _formatSpotSuggestionLocation(Spot spot) {
    final city = spot.city?.trim();
    final trimmedCountryCode = spot.countryCode?.trim();
    final countryCode =
        trimmedCountryCode != null && trimmedCountryCode.isNotEmpty
        ? trimmedCountryCode.toUpperCase()
        : null;
    final address = spot.address?.trim();

    if (city != null &&
        city.isNotEmpty &&
        countryCode != null &&
        countryCode.isNotEmpty) {
      return '$city, $countryCode';
    }
    if (city != null && city.isNotEmpty) {
      return city;
    }
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}';
  }

  Future<void> _selectSpotSuggestion(Map<String, dynamic> suggestion) async {
    final spot = suggestion['spot'];
    if (spot is! Spot) return;

    final controllerToUpdate = _autocompleteController ?? _searchController;
    final newText = spot.name;
    setState(() {
      controllerToUpdate.text = newText;
      controllerToUpdate.selection = TextSelection.fromPosition(
        TextPosition(offset: controllerToUpdate.text.length),
      );
      _searchQuery = newText;
      _isSearchingLocation = false;
    });

    if (_autocompleteFocusNode != null && _autocompleteFocusNode!.hasFocus) {
      _autocompleteFocusNode!.unfocus();
    }

    _lastAutocompleteSpotSelection = DateTime.now();
    await _locateSpot(spot);
    if (spot.id != null) {
      _loadFullSpotInBackground(spot.id!);
    }
  }

  /// Load full spot details in background and update the card when available.
  void _loadFullSpotInBackground(String spotId) {
    _spotServiceRef ??= Provider.of<SpotService>(context, listen: false);
    _spotServiceRef!.getSpotById(spotId).then((fullSpot) {
      if (fullSpot != null && mounted && _selectedSpot?.id == spotId) {
        setState(() {
          _selectedSpot = fullSpot;
          _markers = _rebuildMarkers();
        });
      }
    });
  }

  Future<void> _selectAutocompleteOption(Map<String, dynamic> option) async {
    final optionType = option['optionType'] as String? ?? 'place';
    if (optionType == 'spot') {
      await _selectSpotSuggestion(option);
      return;
    }
    await _selectPlaceSuggestion(option);
  }

  /// Fetches autocomplete options from both geocoding and spot search (Future.wait).
  Future<List<Map<String, dynamic>>> _buildAutocompleteOptions(
    String query,
  ) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    _placesSessionToken ??= const Uuid().v4();

    LatLng? center;
    if (_mapController != null) {
      try {
        final bounds = await _mapController!.getVisibleRegion();
        center = LatLng(
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
        );
      } catch (_) {}
    }

    if (!mounted) return [];

    try {
      final geocoding = Provider.of<GeocodingService>(context, listen: false);
      final spotService = Provider.of<SpotService>(context, listen: false);
      final shouldSearchSpotTitles = trimmedQuery.length >= 2;

      final results = await Future.wait([
        geocoding.placesAutocomplete(
          input: trimmedQuery,
          sessionToken: _placesSessionToken,
          biasLat: center?.latitude,
          biasLng: center?.longitude,
          radiusMeters: 50000,
        ),
        shouldSearchSpotTitles
            ? spotService.searchSpotsByTitle(query: trimmedQuery, limit: 6)
            : Future.value(<Spot>[]),
      ]);

      if (!mounted) return [];

      final locationSuggestions = results[0] as List<Map<String, dynamic>>;
      final matchingSpots = results[1] as List<Spot>;

      final combinedOptions = <Map<String, dynamic>>[
        ...locationSuggestions.map(
          (suggestion) => {...suggestion, 'optionType': 'place'},
        ),
      ];

      for (final spot in matchingSpots) {
        if (spot.id == null) continue;
        combinedOptions.add({
          'optionType': 'spot',
          'description': spot.name,
          'secondary': _formatSpotSuggestionLocation(spot),
          'spot': spot,
        });
      }

      return combinedOptions;
    } catch (e) {
      return [];
    }
  }

  /// Search for location using current search text and navigate to the first result
  Future<void> _searchAndNavigateToLocation() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingLocation = true;
    });

    try {
      final geocoding = Provider.of<GeocodingService>(context, listen: false);

      // Ensure session token
      _placesSessionToken ??= const Uuid().v4();

      // Compute map center bias if possible
      LatLng? center;
      if (_mapController != null) {
        try {
          final bounds = await _mapController!.getVisibleRegion();
          center = LatLng(
            (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
            (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
          );
        } catch (_) {}
      }

      // Get autocomplete suggestions
      final results = await geocoding.placesAutocomplete(
        input: query,
        sessionToken: _placesSessionToken,
        biasLat: center?.latitude,
        biasLng: center?.longitude,
        radiusMeters: 50000,
      );

      // If we have results, select the first one
      if (results.isNotEmpty) {
        // Check if this search came from an initial location query (country/city route)
        final fromInitialQuery =
            widget.initialLocationQuery != null &&
            widget.initialLocationQuery!.isNotEmpty &&
            _searchQuery == widget.initialLocationQuery;
        // Don't let _selectPlaceSuggestion manage loading state since we're managing it here
        await _selectPlaceSuggestion(
          results.first,
          manageLoadingState: false,
          fromInitialQuery: fromInitialQuery,
        );
        // Clear loading state after selection completes
        setState(() {
          _isSearchingLocation = false;
        });
      } else {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching and navigating to location: $e');
      setState(() {
        _isSearchingLocation = false;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    // Only show as denied if it's permanently denied, not if it's just not asked yet
    final isDenied = permission == LocationPermission.deniedForever;
    final isGranted = LocationPermissionUtils.isPermissionGranted(permission);

    if (mounted) {
      setState(() {
        _isLocationPermissionDenied = isDenied;
      });

      // Start or stop location polling based on permission status
      if (isGranted) {
        // Start location polling - it will get the current position
        // The cached location (if available) is used elsewhere (e.g., centering the map)
        _startLocationPolling();
      } else {
        _stopLocationPolling();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    // Check permission status
    final permission = await LocationPermissionUtils.checkAndRequestPermission(
      context: context,
      showErrorMessages: true,
    );

    final isPermissionGranted = LocationPermissionUtils.isPermissionGranted(
      permission,
    );

    if (mounted) {
      setState(() {
        _isLocationPermissionDenied = !isPermissionGranted;
      });

      // Start or stop location polling based on permission status
      if (isPermissionGranted) {
        _startLocationPolling();
      } else {
        _stopLocationPolling();
      }
    }

    if (!isPermissionGranted) {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
      return;
    }

    // First, center on cached location if available
    final searchState = Provider.of<SearchStateService>(context, listen: false);
    final cachedLat = searchState.lastKnownUserLat;
    final cachedLng = searchState.lastKnownUserLng;

    if (cachedLat != null && cachedLng != null && _mapController != null) {
      // Center on cached location immediately
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(cachedLat, cachedLng), zoom: 13.5),
        ),
      );
      _lastKnownZoom = 13.5;
    }

    try {
      // Then get fresh location and center again
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocationPermissionDenied = false;
        });

        // Save to cache
        await searchState.saveLastKnownUserLocation(
          position.latitude,
          position.longitude,
        );
        await _syncLastKnownLocationForAlerts(position);

        // Move camera to fresh user location if map is ready
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 13.5,
              ),
            ),
          );
          _lastKnownZoom = 13.5;
        }
        // Refresh markers to include current location
        _updateVisibleSpots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exploreLocationError('$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  /// Updates the user's location without centering the map
  Future<void> _updateLocationWithoutCentering() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });

        // Save to cache
        final searchState = Provider.of<SearchStateService>(
          context,
          listen: false,
        );
        await searchState.saveLastKnownUserLocation(
          position.latitude,
          position.longitude,
        );
        await _syncLastKnownLocationForAlerts(position);

        // Refresh markers to update location marker position
        _updateVisibleSpots();
      }
    } catch (e) {
      // Silently fail for polling updates - don't show errors to user
      debugPrint('Error updating location during polling: $e');
    }
  }

  Future<void> _syncLastKnownLocationForAlerts(Position position) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated ||
        authService.userProfile?.shareLastKnownLocationForAlerts != true) {
      return;
    }
    final locationsService = Provider.of<UserLocationsOfInterestService>(
      context,
      listen: false,
    );
    await locationsService.upsertLastKnownLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Starts polling for user location periodically
  void _startLocationPolling() {
    // Cancel existing timer if any
    _stopLocationPolling();

    // Poll immediately first
    if (mounted) {
      _updateLocationWithoutCentering();
    }

    // Then poll every 5 seconds
    _locationPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _updateLocationWithoutCentering();
      } else {
        timer.cancel();
      }
    });
  }

  /// Stops polling for user location
  void _stopLocationPolling() {
    _locationPollingTimer?.cancel();
    _locationPollingTimer = null;
  }

  // Load spots and event pins for the current map view.
  Future<void> _loadMapDataForCurrentView() async {
    if (_mapController == null) {
      return;
    }

    setState(() {
      _isLoadingSpotsForView = true;
      _isLoadingEventsForView = true;
    });

    try {
      final bounds = await _mapController!.getVisibleRegion();

      if (!mounted) return;
      final spotService = Provider.of<SpotService>(context, listen: false);
      final eventMapService = Provider.of<EventMapService>(
        context,
        listen: false,
      );
      final searchState = Provider.of<SearchStateService>(
        context,
        listen: false,
      );

      List<String> selectedFolders = [];
      if (_selectedSpotSource != null && _selectedSpotSource!.isNotEmpty) {
        selectedFolders = searchState.getSelectedFoldersForSource(
          _selectedSpotSource!,
        );
      }

      final minLat = bounds.southwest.latitude;
      final maxLat = bounds.northeast.latitude;
      final minLng = bounds.southwest.longitude;
      final maxLng = bounds.northeast.longitude;

      final results = await Future.wait([
        spotService.getTopRankedSpotsInBounds(
          minLat,
          maxLat,
          minLng,
          maxLng,
          limit: 100,
          filterArea: _filterArea ?? 'amenities',
          spotSource: (_filterArea ?? 'amenities') == 'amenities'
              ? null
              : _selectedSpotSource,
          folders: selectedFolders.isEmpty ? null : selectedFolders,
          spotAccess: _spotAccess.isEmpty ? null : _spotAccess,
          spotFacilitiesCovered: _spotFacilitiesCovered,
          spotFacilitiesLighting: _spotFacilitiesLighting,
          spotFacilitiesWaterTap: _spotFacilitiesWaterTap,
          spotFacilitiesToilet: _spotFacilitiesToilet,
          spotFacilitiesParking: _spotFacilitiesParking,
          goodFor: _goodFor.isEmpty ? null : _goodFor,
          spotFeatures: _spotFeatures.isEmpty ? null : _spotFeatures,
        ),
        eventMapService.getEventsInBounds(
          minLat,
          maxLat,
          minLng,
          maxLng,
          limit: 100,
        ),
      ]);

      final ranked = results[0] as Map<String, dynamic>;
      final eventsResult = results[1] as EventsInBoundsResult;

      _loadedSpots = (ranked['spots'] as List<Spot>?) ?? <Spot>[];
      _totalSpotsInView = ranked['totalCount'] as int?;
      _bestShownCount = ranked['shownCount'] as int?;

      _loadedEventPins = eventsResult.pins;
      _totalEventPinsInView = eventsResult.totalCount;
      _eventCountInView = eventsResult.eventCount;
      _eventPinBySpotId = eventPinsBySpotId(_loadedEventPins);
      _visibleEvents = dedupePinsByEventId(_loadedEventPins);

      _updateVisibleSpots();
    } catch (e) {
      debugPrint('Error loading map data for current view: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSpotsForView = false;
          _isLoadingEventsForView = false;
        });
      }
    }
  }

  void _updateVisibleSpots() {
    setState(() {
      _visibleSpots = _loadedSpots;
      _markers = _rebuildMarkers();
    });
  }

  bool get _isLoadingMapData =>
      _isLoadingSpotsForView || _isLoadingEventsForView;

  Widget _buildFilters() {
    final l10n = AppLocalizations.of(context)!;
    final selectedFilterArea = _filterArea ?? 'amenities';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exploreFilterBy,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String?>(
          segments: [
            ButtonSegment(
              value: 'amenities',
              label: Text(l10n.exploreFilterAmenities),
              icon: const Icon(Icons.workspace_premium),
            ),
            ButtonSegment(
              value: 'source',
              label: Text(l10n.exploreFilterSources),
              icon: const Icon(Icons.folder),
            ),
          ],
          selected: {selectedFilterArea},
          onSelectionChanged: (Set<String?> selected) {
            final value = selected.first;
            Provider.of<SearchStateService>(
              context,
              listen: false,
            ).setFilterArea(value);
            setState(() {
              _filterArea = value;
            });
            if (value == 'source') {
              _ensureSyncSourcesLoaded();
            }
            // Defer spot reload so the tab switch paints immediately
            if (_mapController != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _mapController != null) {
                  _loadMapDataForCurrentView();
                }
              });
            }
          },
        ),
        const SizedBox(height: 16),
        if (selectedFilterArea == 'amenities')
          _buildAmenitiesFilters()
        else
          Consumer<SyncSourceService>(
            builder: (context, syncService, child) {
              final summaries = List<SyncSourceSummary>.from(
                syncService.sourceSummaries,
              )..sort((a, b) => a.name.compareTo(b.name));
              return _buildSourceFilters(syncService, summaries);
            },
          ),
      ],
    );
  }

  Widget _buildAmenitiesFilters() {
    return Consumer<SearchStateService>(
      builder: (context, searchState, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAccessFilterCard(searchState),
            const SizedBox(height: 12),
            _buildFacilitiesFilterCard(searchState),
            const SizedBox(height: 12),
            _buildAttributesFilterCard(searchState),
          ],
        );
      },
    );
  }

  Widget _buildAccessFilterCard(SearchStateService searchState) {
    final l10n = AppLocalizations.of(context)!;
    final keys = SpotAttributes.getKeys('access');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exploreSpotAccessTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exploreSpotAccessSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: l10n.exploreFilterAny,
                  icon: Icons.check_circle_outline,
                  selected: _spotAccess.isEmpty,
                  onTap: () {
                    searchState.clearSpotAccess();
                    setState(() => _spotAccess = []);
                    if (_mapController != null) _loadMapDataForCurrentView();
                  },
                ),
                ...keys.map((key) {
                  final label = SpotAttributes.getLabel('access', key);
                  final icon = SpotAttributes.getIcon('access', key);
                  final description = SpotAttributes.getDescription(
                    'access',
                    key,
                  );
                  final selected = _spotAccess.contains(key);
                  Color backgroundColor;
                  Color textColor;
                  if (selected) {
                    switch (key) {
                      case 'public':
                        backgroundColor = Colors.green.withValues(alpha: 0.1);
                        textColor = Colors.green.shade700;
                        break;
                      case 'restricted':
                        backgroundColor = Colors.orange.withValues(alpha: 0.1);
                        textColor = Colors.orange.shade700;
                        break;
                      case 'paid':
                        backgroundColor = Colors.blue.withValues(alpha: 0.1);
                        textColor = Colors.blue.shade700;
                        break;
                      default:
                        backgroundColor = Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3);
                        textColor = Theme.of(context).colorScheme.primary;
                    }
                  } else {
                    backgroundColor = Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest;
                    textColor = Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6);
                  }
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () {
                        searchState.toggleSpotAccess(key);
                        setState(() {
                          if (selected) {
                            _spotAccess = List<String>.from(_spotAccess)
                              ..remove(key);
                          } else {
                            _spotAccess = List<String>.from(_spotAccess)
                              ..add(key);
                          }
                        });
                        if (_mapController != null) _loadMapDataForCurrentView();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: textColor),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesFilterCard(SearchStateService searchState) {
    final l10n = AppLocalizations.of(context)!;
    final facilityKeys = [
      'covered',
      'lighting',
      'water_tap',
      'toilet',
      'parking',
    ];
    bool getFacility(String key) {
      switch (key) {
        case 'covered':
          return _spotFacilitiesCovered == true;
        case 'lighting':
          return _spotFacilitiesLighting == true;
        case 'water_tap':
          return _spotFacilitiesWaterTap == true;
        case 'toilet':
          return _spotFacilitiesToilet == true;
        case 'parking':
          return _spotFacilitiesParking == true;
        default:
          return false;
      }
    }

    void setFacility(String key, bool value) {
      final v = value ? true : null;
      switch (key) {
        case 'covered':
          searchState.setSpotFacilitiesCovered(v);
          setState(() => _spotFacilitiesCovered = v);
          break;
        case 'lighting':
          searchState.setSpotFacilitiesLighting(v);
          setState(() => _spotFacilitiesLighting = v);
          break;
        case 'water_tap':
          searchState.setSpotFacilitiesWaterTap(v);
          setState(() => _spotFacilitiesWaterTap = v);
          break;
        case 'toilet':
          searchState.setSpotFacilitiesToilet(v);
          setState(() => _spotFacilitiesToilet = v);
          break;
        case 'parking':
          searchState.setSpotFacilitiesParking(v);
          setState(() => _spotFacilitiesParking = v);
          break;
      }
      if (_mapController != null) _loadMapDataForCurrentView();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exploreSpotFacilitiesTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exploreSpotFacilitiesSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facilityKeys.map((key) {
                final label = SpotAttributes.getLabel('facilities', key);
                final icon = SpotAttributes.getIcon('facilities', key);
                final description = SpotAttributes.getDescription(
                  'facilities',
                  key,
                );
                final selected = getFacility(key);
                Color backgroundColor;
                Color textColor;
                IconData statusIcon;
                if (selected) {
                  backgroundColor = Colors.green.withValues(alpha: 0.1);
                  textColor = Colors.green.shade700;
                  statusIcon = Icons.check;
                } else {
                  backgroundColor = Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest;
                  textColor = Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6);
                  statusIcon = Icons.help_outline;
                }
                return Tooltip(
                  message: description,
                  child: GestureDetector(
                    onTap: () => setFacility(key, !selected),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: textColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: textColor),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 4),
                            Icon(statusIcon, size: 14, color: textColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final backgroundColor = selected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                (selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline)
                    .withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributesFilterCard(SearchStateService searchState) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exploreAttributesTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exploreAttributesSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'goodFor',
                  label: Text(l10n.exploreGoodForSegment),
                ),
                ButtonSegment(
                  value: 'spotFeatures',
                  label: Text(l10n.exploreSpotFeaturesSegment),
                ),
              ],
              selected: {_attributeFilterMode},
              onSelectionChanged: (Set<String> selected) {
                final mode = selected.first;
                searchState.setAttributeFilterMode(mode);
                setState(() {
                  _attributeFilterMode = mode;
                  if (mode == 'goodFor') {
                    _spotFeatures = [];
                  } else {
                    _goodFor = [];
                  }
                });
                if (_mapController != null) _loadMapDataForCurrentView();
              },
            ),
            const SizedBox(height: 12),
            if (_attributeFilterMode == 'spotFeatures')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SpotAttributes.getKeys('features').map((key) {
                  final label = SpotAttributes.getLabel('features', key);
                  final icon = SpotAttributes.getIcon('features', key);
                  final description = SpotAttributes.getDescription(
                    'features',
                    key,
                  );
                  final selected = _spotFeatures.contains(key);
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () {
                        searchState.toggleSpotFeatures(key);
                        setState(() {
                          if (selected) {
                            _spotFeatures = List<String>.from(_spotFeatures)
                              ..remove(key);
                          } else {
                            _spotFeatures = List<String>.from(_spotFeatures)
                              ..add(key);
                          }
                        });
                        if (_mapController != null) _loadMapDataForCurrentView();
                      },
                      child: _buildAttributeChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SpotAttributes.getKeys('goodFor').map((key) {
                  final label = SpotAttributes.getLabel('goodFor', key);
                  final icon = SpotAttributes.getIcon('goodFor', key);
                  final description = SpotAttributes.getDescription(
                    'goodFor',
                    key,
                  );
                  final selected = _goodFor.contains(key);
                  return Tooltip(
                    message: description,
                    child: GestureDetector(
                      onTap: () {
                        searchState.toggleGoodFor(key);
                        setState(() {
                          if (selected) {
                            _goodFor = List<String>.from(_goodFor)..remove(key);
                          } else {
                            _goodFor = List<String>.from(_goodFor)..add(key);
                          }
                        });
                        if (_mapController != null) _loadMapDataForCurrentView();
                      },
                      child: _buildAttributeChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeChip({
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    final backgroundColor = selected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              (selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline)
                  .withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFilters(
    SyncSourceService syncService,
    List<SyncSourceSummary> summaries,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exploreSpotSourceLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        if (syncService.isLoadingSummaries && summaries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (syncService.summariesError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.exploreSourcesLoadError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _ensureSyncSourcesLoaded(force: true),
                  child: Text(l10n.profileRetry),
                ),
              ],
            ),
          )
        else
          Consumer<SearchStateService>(
            builder: (context, searchState, child) {
              return RadioGroup<String?>(
                groupValue: _selectedSpotSource,
                onChanged: (String? value) {
                  setState(() {
                    _selectedSpotSource = value;
                  });
                  Provider.of<SearchStateService>(
                    context,
                    listen: false,
                  ).setSelectedSpotSource(value);
                  // Reload spots with new filter
                  _loadMapDataForCurrentView();
                },
                child: SizedBox(
                  height: (MediaQuery.of(context).size.height * 0.5).clamp(
                    200.0,
                    450.0,
                  ),
                  child: ListView.builder(
                    itemCount: 2 + summaries.length,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RadioListTile<String?>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.exploreAllSources),
                          value: null,
                        );
                      }
                      if (index == 1) {
                        return RadioListTile<String?>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.exploreParkourSpotNative),
                          value: "",
                        );
                      }
                      final summary = summaries[index - 2];
                      final isWideScreen =
                          MediaQuery.of(context).size.width > 600;
                      final isSelected = _selectedSpotSource == summary.id;
                      final hasFolders =
                          summary.allFolders != null &&
                          summary.allFolders!.isNotEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<String?>(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isWideScreen)
                                  Text(summary.name)
                                else
                                  Expanded(child: Text(summary.name)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () =>
                                      _showSourceDetailsDialog(summary.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            value: summary.id,
                          ),
                          if (isSelected && hasFolders)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 40,
                                top: 8,
                                bottom: 8,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final selectedFolders = searchState
                                          .getSelectedFoldersForSource(
                                            summary.id,
                                          );
                                      final isAllSelected =
                                          selectedFolders.isEmpty;
                                      return FilterChip(
                                        label: Text(l10n.exploreAllFolders),
                                        selected: isAllSelected,
                                        onSelected: (selected) {
                                          if (selected && !isAllSelected) {
                                            searchState.clearFoldersForSource(
                                              summary.id,
                                            );
                                            if (_mapController != null) {
                                              _loadMapDataForCurrentView();
                                            }
                                          }
                                        },
                                        selectedColor: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        checkmarkColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        labelStyle: TextStyle(
                                          color: isAllSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                  ...(summary.allFolders ?? []).map((folder) {
                                    final isFolderSelected = searchState
                                        .isFolderSelectedForSource(
                                          summary.id,
                                          folder,
                                        );
                                    return FilterChip(
                                      label: Text(folder),
                                      selected: isFolderSelected,
                                      onSelected: (selected) {
                                        searchState.toggleFolderForSource(
                                          summary.id,
                                          folder,
                                        );
                                        if (_mapController != null) {
                                          _loadMapDataForCurrentView();
                                        }
                                      },
                                      selectedColor: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      checkmarkColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      labelStyle: TextStyle(
                                        color: isFolderSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : null,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Set<Marker> _rebuildMarkers() {
    final markers = <Marker>{};
    final visibleSpotIds = _visibleSpots
        .map((s) => s.id)
        .whereType<String>()
        .toSet();
    final upgradedSpotIds = <String>{};

    for (final spot in MarkerIconUtils.sortSpotsForMapDrawOrder(_visibleSpots)) {
      final bool isSelected = _selectedSpot?.id != null
          ? _selectedSpot!.id == spot.id
          : _selectedSpot?.name == spot.name;
      final bool isHighlighted =
          spot.id != null && _highlightedSpotIds.contains(spot.id);
      final eventPin =
          spot.id != null ? _eventPinBySpotId[spot.id!] : null;
      final bool hasEvent = eventPin != null;

      BitmapDescriptor icon;
      if (hasEvent && !isSelected && !isHighlighted) {
        icon = _eventSpotIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isSelected && isHighlighted) {
        icon =
            _spotSelectedHighlightedIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isSelected && hasEvent) {
        icon = _eventSpotSelectedIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isSelected) {
        icon = _spotSelectedIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isHighlighted) {
        icon = _spotHighlightedIcon ?? BitmapDescriptor.defaultMarker;
      } else {
        icon = _spotDefaultIcon ?? BitmapDescriptor.defaultMarker;
      }

      if (hasEvent && spot.id != null) {
        upgradedSpotIds.add(spot.id!);
      }

      markers.add(
        Marker(
          markerId: MarkerId(spot.id ?? spot.name),
          position: LatLng(spot.latitude, spot.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: isSelected ? 2 : (hasEvent ? 1 : (isHighlighted ? 1 : 0)),
          onTap: () {
            if (_isBottomSheetOpen || _showFiltersDialog) return;
            setState(() {
              _selectedSpot = spot;
              _showListPreview = false;
              _markers = _rebuildMarkers();
            });
          },
        ),
      );
    }

    for (final pin in _loadedEventPins) {
      if (pin.kind == EventMapPinKind.spot &&
          pin.spotId != null &&
          visibleSpotIds.contains(pin.spotId) &&
          upgradedSpotIds.contains(pin.spotId)) {
        continue;
      }

      final markerId = pin.kind == EventMapPinKind.venue
          ? 'event_venue_${pin.eventId}'
          : 'event_spot_${pin.id}';
      final icon = pin.kind == EventMapPinKind.venue
          ? (_eventVenueIcon ?? BitmapDescriptor.defaultMarker)
          : (_eventSpotIcon ?? BitmapDescriptor.defaultMarker);

      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: LatLng(pin.latitude, pin.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: pin.kind == EventMapPinKind.venue ? 3 : 1,
          onTap: () {
            if (_isBottomSheetOpen || _showFiltersDialog) return;
            context.push('/event/${pin.eventId}');
          },
        ),
      );
    }

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon:
              _userLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 9999,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.exploreCurrentLocationSnackbar,
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    }

    if (_longPressedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('long_pressed_location'),
          position: _longPressedLocation!,
          icon: _addSpotPinIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 10000,
        ),
      );
    }

    return markers;
  }

  Future<void> _loadUserLocationIcon() async {
    try {
      final icon = await MarkerIconUtils.createUserLocationIcon(
        size: 24,
        fillColor: Colors.blue,
      );
      if (mounted) {
        setState(() {
          _userLocationIcon = icon;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
    }
  }

  Future<void> _loadSpotIcons() async {
    try {
      final double browsePinHeight = MarkerIconUtils.mapPinBrowseLogicalHeight;
      final BitmapDescriptor normalPin = await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinNormalAsset,
        fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor listPin = await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinListAsset,
        fallbackFill: MarkerIconUtils.mapPinListFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor normalSelectedPin =
          await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinNormalSelectedAsset,
        fallbackFill: MarkerIconUtils.mapPinNormalFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor listSelectedPin =
          await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinListSelectedAsset,
        fallbackFill: MarkerIconUtils.mapPinListFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor addPin = await MarkerIconUtils.loadMapPinPng(
        MarkerIconUtils.mapPinAddAsset,
        fallbackFill: MarkerIconUtils.mapPinAddFallbackFill,
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor eventVenuePin =
          await MarkerIconUtils.loadEventVenueMapPin(
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor eventSpotPin =
          await MarkerIconUtils.loadSpotEventMapPin(
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor eventSpotSelectedPin =
          await MarkerIconUtils.loadSpotEventSelectedMapPin(
        logicalHeight: browsePinHeight,
      );
      if (mounted) {
        setState(() {
          _spotDefaultIcon = normalPin;
          _spotSelectedIcon = normalSelectedPin;
          _spotHighlightedIcon = listPin;
          _spotSelectedHighlightedIcon = listSelectedPin;
          _addSpotPinIcon = addPin;
          _eventVenueIcon = eventVenuePin;
          _eventSpotIcon = eventSpotPin;
          _eventSpotSelectedIcon = eventSpotSelectedPin;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
    }
  }

  Future<void> _loadSpotList(String listId) async {
    try {
      final spotListService = Provider.of<SpotListService>(
        context,
        listen: false,
      );
      final list = await spotListService.getSpotListById(listId);

      if (!mounted) return;

      if (list == null) {
        setState(() {
          _selectedList = null;
          _selectedListName = null;
          _showListPreview = false;
          _highlightedSpotIds.clear();
          _markers = _rebuildMarkers();
        });

        if (_selectedListId == listId) {
          _searchStateServiceRef?.setSelectedListId(null);
        }
        return;
      }

      setState(() {
        _selectedList = list;
        _selectedListName = list.name;
        _highlightedSpotIds = list.effectiveSpotIds.toSet();
        // Rebuild markers to reflect highlighting
        _markers = _rebuildMarkers();
      });
    } catch (e) {
      debugPrint('Error loading spot list: $e');
    }
  }

  /// Open the spot list preview card for a given list ID
  Future<void> _openSpotListPreview(String listId) async {
    // Load the list if not already loaded
    if (_selectedListId != listId || _selectedList == null) {
      await _loadSpotList(listId);
    }

    if (!mounted || _selectedList == null) return;

    // Collapse bottom sheet if open
    if (_isBottomSheetOpen) {
      _toggleBottomSheet();
    }

    setState(() {
      _showListPreview = true;
      // Close spot detail if open
      _selectedSpot = null;
    });

    // Fit map to show all spots in the list
    if (_selectedList != null && _selectedList!.effectiveSpotIds.isNotEmpty) {
      await _fitMapToSpotList(_selectedList!.effectiveSpotIds);
    }
  }

  /// Fit the map to show all spots in a list with 5% padding
  Future<void> _fitMapToSpotList(List<String> spotIds) async {
    if (spotIds.isEmpty || _mapController == null) return;

    try {
      // Fetch all spots by their IDs
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spots = await Future.wait(
        spotIds.map((id) => spotService.getSpotById(id)),
      );

      // Filter out null spots (spots that don't exist)
      final validSpots = spots.whereType<Spot>().toList();

      if (validSpots.isEmpty) return;

      // Calculate bounds with 5% padding
      final bounds = calculateBoundsForSpots(validSpots);
      if (bounds == null) return;

      // Fit the map to the bounds with padding
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0), // 50px padding
      );
    } catch (e) {
      debugPrint('Error fitting map to spot list: $e');
    }
  }

  void _clearSpotListSelection() {
    setState(() {
      _selectedList = null;
      _selectedListId = null;
      _selectedListName = null;
      _showListPreview = false;
      _highlightedSpotIds.clear();
      _markers = _rebuildMarkers();
    });

    // Update SearchStateService to persist the change
    final searchState = _searchStateServiceRef;
    if (searchState != null) {
      searchState.setSelectedListId(null);
    }

    // Update URL query parameter, preserving existing params
    try {
      final routerState = GoRouterState.of(context);
      final currentUri = routerState.uri;
      final queryParams = Map<String, String>.from(currentUri.queryParameters);
      queryParams.remove('listId');

      // Build new URL with updated query params
      final queryString = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      final newPath = queryString.isNotEmpty
          ? '${currentUri.path}?$queryString'
          : currentUri.path;

      context.go(newPath);
    } catch (e) {
      // Fallback: simple URL update
      context.go('/explore');
    }
  }

  void _toggleBottomSheet() {
    if (_isBottomSheetOpen) {
      _bottomSheetAnimationController.reverse();
    } else {
      _bottomSheetAnimationController.forward();
    }
    setState(() {
      _isBottomSheetOpen = !_isBottomSheetOpen;
      // Clear selected spot when opening bottom sheet
      if (_isBottomSheetOpen) {
        _selectedSpot = null;
      }
    });
  }

  // Public API to check if bottom sheet is open
  bool get isBottomSheetOpen => _isBottomSheetOpen;

  // Public API so parent can collapse on Explore tab re-tap
  void collapseBottomSheetIfOpen() {
    if (_isBottomSheetOpen) {
      _toggleBottomSheet();
    }
  }

  // Public API so parent can open bottom sheet if closed
  void openBottomSheetIfClosed() {
    if (!_isBottomSheetOpen) {
      _toggleBottomSheet();
    }
  }

  // Public API to check if spot detail is open
  bool get isSpotDetailOpen => _selectedSpot != null;

  // Public API so parent can close spot detail if open
  void closeSpotDetailIfOpen() {
    if (_selectedSpot != null && !_isBottomSheetOpen) {
      setState(() {
        _selectedSpot = null;
        _markers = _rebuildMarkers();
      });
    }
  }

  // Public API to close spot detail regardless of bottom sheet state
  void closeSpotDetail() {
    if (_selectedSpot != null) {
      setState(() {
        _selectedSpot = null;
        _markers = _rebuildMarkers();
      });
    }
  }

  Timer? _cameraMoveDebounce;

  void _onMapCameraMove(CameraPosition position) {
    // Persist camera position
    final searchState = Provider.of<SearchStateService>(context, listen: false);
    searchState.saveMapCamera(
      position.target.latitude,
      position.target.longitude,
      position.zoom,
    );
    _lastKnownZoom = position.zoom;

    // Debounce loading spots to avoid too many requests while user is panning
    _cameraMoveDebounce?.cancel();
    _cameraMoveDebounce = Timer(const Duration(milliseconds: 1000), () {
      _loadMapDataForCurrentView();
    });
  }

  // Removed: _nextImage and _previousImage – image paging handled inside SpotCard

  void _handleDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final currentY = details.globalPosition.dy;
    final deltaY = currentY - _dragStartY;
    final sensitivity = 2.0; // Higher sensitivity for better responsiveness

    // Only trigger if drag distance is significant
    if (deltaY.abs() > 20) {
      if (deltaY < -sensitivity && !_isBottomSheetOpen) {
        // Dragging up - expand
        _toggleBottomSheet();
        _isDragging = false;
      } else if (deltaY > sensitivity && _isBottomSheetOpen) {
        // Dragging down - collapse
        _toggleBottomSheet();
        _isDragging = false;
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  Future<void> _handleLongPress(LatLng position) async {
    // Don't show add spot button if filter dialog is open
    if (_showFiltersDialog) {
      _longPressHandled = false; // Reset if we're not going to handle it
      return;
    }
    // Note: _longPressHandled is already set to true in the timer callback
    // before this async function is called, so onPointerUp won't interfere

    // Collapse bottom sheet if open (similar to when spot detail card is shown)
    if (_isBottomSheetOpen) {
      await _bottomSheetAnimationController.reverse();
      if (!mounted) {
        _longPressHandled = false; // Reset if unmounted
        return;
      }
      setState(() {
        _isBottomSheetOpen = false;
      });
    }
    // Set the long pressed location to show the add spot button
    if (mounted) {
      setState(() {
        _longPressedLocation = position;
        // Rebuild markers to include the long-pressed location marker
        _markers = _rebuildMarkers();
      });
    }
  }

  Future<void> _locateSpot(Spot spot) async {
    // Collapse bottom sheet if open
    if (_isBottomSheetOpen) {
      await _bottomSheetAnimationController.reverse();
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    }

    // Center map on spot with fluid zoom-in (no zoom-out)
    if (_mapController != null) {
      const double desiredZoom = 15.0;
      final double targetZoom = _lastKnownZoom < desiredZoom
          ? desiredZoom
          : _lastKnownZoom;
      // Step 1: pan to target at current zoom (smoother motion)
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(spot.latitude, spot.longitude)),
      );
      // Step 2: if we need to zoom in, do that as a separate animation
      if (_lastKnownZoom < targetZoom) {
        await _mapController!.animateCamera(CameraUpdate.zoomTo(targetZoom));
      }
    }

    // Select the spot and refresh markers to show detail card overlay
    if (mounted) {
      setState(() {
        _selectedSpot = spot;
        _markers = _rebuildMarkers();
      });
    }
  }

  Future<void> _locateSpotById(String spotId) async {
    // Wait for spot service to be available
    _spotServiceRef ??= Provider.of<SpotService>(context, listen: false);

    if (_spotServiceRef == null) return;

    try {
      final spot = await _spotServiceRef!.getSpotById(spotId);
      if (spot != null && mounted) {
        await _locateSpot(spot);
        // Clear the query parameter from URL after successful location
        if (mounted) {
          context.go('/explore');
        }
      }
    } catch (e) {
      // Ignore errors - spot might not be found or service not ready
      if (mounted) {
        debugPrint('Failed to locate spot $spotId: $e');
      }
    }
  }

  Widget _buildSpotsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600; // Use grid layout on wider screens

    if (useGrid) {
      // Calculate optimal grid dimensions based on screen size
      final maxCrossAxisExtent = 480.0;
      final mainAxisExtent = 440.0; // Height to accommodate bottom content

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          mainAxisExtent: mainAxisExtent,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _visibleSpots.length,
        itemBuilder: (context, index) {
          final spot = _visibleSpots[index];
          final bool isHighlighted =
              spot.id != null && _highlightedSpotIds.contains(spot.id);
          return SpotCard(
            spot: spot,
            showCheckInPresence: true,
            upcomingEventPin: _upcomingEventPinForSpot(spot),
            spotListId: isHighlighted ? _selectedListId : null,
            spotListName: isHighlighted ? _selectedListName : null,
            onSpotListTap: isHighlighted && _selectedListId != null
                ? () => _openSpotListPreview(_selectedListId!)
                : null,
            onTapWithImageIndex: (imageIndex) {
              // Center map on selected spot
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(LatLng(spot.latitude, spot.longitude)),
              );
              // Navigate to spot detail using proper URL format with image index
              final baseUrl = UrlService.generateNavigationUrl(
                spot.id!,
                countryCode: spot.countryCode,
                city: spot.city,
              );
              final navigationUrl = imageIndex > 0
                  ? '$baseUrl?imageIndex=$imageIndex'
                  : baseUrl;
              context.push(navigationUrl);
            },
            onLocate: () => _locateSpot(spot),
          );
        },
      );
    } else {
      // Use list layout on narrower screens
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _visibleSpots.length,
        itemBuilder: (context, index) {
          final spot = _visibleSpots[index];
          final bool isHighlighted =
              spot.id != null && _highlightedSpotIds.contains(spot.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SpotCard(
              spot: spot,
              showCheckInPresence: true,
              upcomingEventPin: _upcomingEventPinForSpot(spot),
              spotListId: isHighlighted ? _selectedListId : null,
              spotListName: isHighlighted ? _selectedListName : null,
              onSpotListTap: isHighlighted && _selectedListId != null
                  ? () => _openSpotListPreview(_selectedListId!)
                  : null,
              onTapWithImageIndex: (imageIndex) {
                // Center map on selected spot
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(LatLng(spot.latitude, spot.longitude)),
                );
                // Navigate to spot detail using proper URL format with image index
                final baseUrl = UrlService.generateNavigationUrl(
                  spot.id!,
                  countryCode: spot.countryCode,
                  city: spot.city,
                );
                final navigationUrl = imageIndex > 0
                    ? '$baseUrl?imageIndex=$imageIndex'
                    : baseUrl;
                context.push(navigationUrl);
              },
              onLocate: () => _locateSpot(spot),
            ),
          );
        },
      );
    }
  }

  EventMapPin? _upcomingEventPinForSpot(Spot spot) {
    final id = spot.id;
    if (id == null) return null;
    return _eventPinBySpotId[id];
  }

  Widget _buildEventsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _visibleEvents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pin = _visibleEvents[index];
        return ExploreEventListTile(
          pin: pin,
          onLocate: () {
            locateEventPinOnMap(_mapController, pin);
          },
        );
      },
    );
  }

  Widget _buildExploreEventsEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.exploreNoEventsArea,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.exploreNoEventsAreaHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  int _exploreSpotCountForHeader() =>
      _totalSpotsInView ?? _visibleSpots.length;

  int _exploreEventCountForHeader() =>
      _eventCountInView ?? _visibleEvents.length;

  String? _exploreSpotsSegmentSuffix(AppLocalizations l10n) {
    if (_totalSpotsInView != null &&
        _bestShownCount != null &&
        _bestShownCount! < _totalSpotsInView!) {
      return l10n.exploreMapBestShownParenthetical(_bestShownCount!).trim();
    }
    return null;
  }

  String? _exploreEventsSegmentSuffix(AppLocalizations l10n) {
    final pinTotal = _totalEventPinsInView;
    final shownPins = _loadedEventPins.length;
    if (pinTotal != null && shownPins < pinTotal) {
      return l10n.exploreMapBestShownParenthetical(shownPins).trim();
    }
    return null;
  }

  Widget _buildSpotListPreviewCard({required double maxWidth}) {
    if (_selectedList == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final spotCount = _selectedList!.effectiveSpotIds.length;
    final spotCountText = l10n.exploreSpotCountShort(spotCount);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: PointerInterceptor(
        child: InkWell(
          onTap: _selectedListId != null
              ? () {
                  // Navigate to full spot list detail page
                  context.push('/list/$_selectedListId');
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.list,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedList!.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showListPreview = false;
                          });
                        },
                        tooltip: AppLocalizations.of(
                          context,
                        )!.exploreCloseTooltip,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description if available
                  if (_selectedList!.description != null &&
                      _selectedList!.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _selectedList!.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Spot count
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        spotCountText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // On mobile, don't resize when keyboard opens - the search bar is at top and would be
      // pushed out of view when the bottom sheet is expanded. Let the keyboard overlay instead.
      resizeToAvoidBottomInset: !MobileDetectionService.isMobileDevice,
      body: Stack(
        children: [
          // Determine initial camera position - use persisted state, user location, or default
          Consumer<SearchStateService>(
            builder: (context, searchState, child) {
              LatLng initialTarget = const LatLng(
                AppConfig.defaultMapCenterLat,
                AppConfig.defaultMapCenterLng,
              ); // Default center location
              double initialZoom = 14;

              // Use persisted camera position if available
              if (searchState.centerLat != null &&
                  searchState.centerLng != null &&
                  searchState.zoom != null) {
                initialTarget = LatLng(
                  searchState.centerLat!,
                  searchState.centerLng!,
                );
                initialZoom = searchState.zoom!;
              }
              // Otherwise try to use current user location
              else if (_currentPosition != null) {
                initialTarget = LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                );
                initialZoom = 15;
              }

              final CameraPosition initialCameraPosition = CameraPosition(
                target: initialTarget,
                zoom: initialZoom,
              );

              return Stack(
                children: [
                  // Map View
                  GoogleMap(
                    initialCameraPosition: initialCameraPosition,
                    mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled:
                        !_isBottomSheetOpen &&
                        _selectedSpot == null &&
                        !_showListPreview &&
                        !_showFiltersDialog, // Disable location button when expanded, spot detail is open, list preview is open, or filters dialog is open
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        (_selectedSpot == null && !_showListPreview ||
                            !MobileDetectionService.isMobileDevice),
                    scrollGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        (_selectedSpot == null && !_showListPreview ||
                            !MobileDetectionService.isMobileDevice),
                    rotateGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        (_selectedSpot == null && !_showListPreview ||
                            !MobileDetectionService.isMobileDevice),
                    tiltGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        (_selectedSpot == null && !_showListPreview ||
                            !MobileDetectionService.isMobileDevice),
                    liteModeEnabled: kIsWeb,
                    compassEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _lastKnownZoom = initialCameraPosition.zoom;

                      // Trigger location search if initialLocationQuery is provided
                      if (widget.initialLocationQuery != null &&
                          widget.initialLocationQuery!.isNotEmpty) {
                        // Wait a bit for the map to be fully ready
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted && _mapController != null) {
                            _searchAndNavigateToLocation();
                          }
                        });
                      }

                      // Open spot list preview if listId came from URL
                      if (widget.initialListId != null &&
                          _selectedListId == widget.initialListId) {
                        // Wait a bit for the map to be fully ready
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted &&
                              _mapController != null &&
                              _selectedListId != null) {
                            _openSpotListPreview(_selectedListId!);
                          }
                        });
                      }

                      // Check for locateSpotId query parameter if not already set
                      if (_spotIdToLocate == null) {
                        try {
                          final routerState = GoRouterState.of(context);
                          final locateSpotId =
                              routerState.uri.queryParameters['locateSpotId'];
                          if (locateSpotId != null && locateSpotId.isNotEmpty) {
                            _spotIdToLocate = locateSpotId;
                          }
                        } catch (e) {
                          // Ignore errors when accessing router state
                        }
                      }

                      // Load spots for the current view after a short delay to ensure map is ready
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _loadMapDataForCurrentView();

                        // If we have a spot ID to locate, locate it after spots are loaded
                        if (_spotIdToLocate != null) {
                          final spotId = _spotIdToLocate!;
                          _spotIdToLocate =
                              null; // Clear before attempting to locate
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _locateSpotById(spotId);
                          });
                        }
                      });

                      // Restore persisted camera after map is ready (in case state loaded late)
                      final state = Provider.of<SearchStateService>(
                        context,
                        listen: false,
                      );
                      if (state.centerLat != null &&
                          state.centerLng != null &&
                          state.zoom != null) {
                        controller.moveCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(
                                state.centerLat!,
                                state.centerLng!,
                              ),
                              zoom: state.zoom!,
                            ),
                          ),
                        );
                      } else {
                        // If no persisted camera and no initial location query (city/country URL),
                        // try to center on user's current location
                        // Don't auto-center on user location if they came from a city/country URL
                        if (widget.initialLocationQuery == null ||
                            widget.initialLocationQuery!.isEmpty) {
                          _getCurrentLocation();
                        }
                      }
                    },
                    onCameraMove: (CameraPosition position) {
                      _onMapCameraMove(position);
                    },
                    onTap: (LatLng position) {
                      // On mobile web, tap on autocomplete can pass through when overlay dismisses.
                      // Ignore map taps for a short window after selecting a spot from autocomplete.
                      if (kIsWeb &&
                          MobileDetectionService.isMobileDevice &&
                          _lastAutocompleteSpotSelection != null &&
                          DateTime.now()
                                  .difference(_lastAutocompleteSpotSelection!)
                                  .inMilliseconds <
                              400) {
                        _lastAutocompleteSpotSelection = null;
                        return;
                      }
                      // Dismiss spot detail card or list preview when map is tapped (but not when markers are tapped)
                      if ((_selectedSpot != null || _showListPreview) &&
                          !_isBottomSheetOpen) {
                        setState(() {
                          _selectedSpot = null;
                          _showListPreview = false;
                          // Rebuild markers to clear selection color
                          _markers = _rebuildMarkers();
                        });
                      }
                      // Clear long press location on regular tap
                      // The overlay handles most dismissals, but this is a safety net
                      if (_longPressedLocation != null && !_longPressHandled) {
                        setState(() {
                          _longPressedLocation = null;
                          _longPressHandled = false;
                          // Rebuild markers to remove the long-pressed location marker
                          _markers = _rebuildMarkers();
                        });
                      }
                    },
                    onLongPress: (LatLng position) async {
                      // This works on desktop web (right click) but not on mobile web
                      // Mobile web uses the GestureDetector overlay below
                      if (kIsWeb && MobileDetectionService.isMobileDevice) {
                        return; // Let the overlay handle it on mobile web
                      }
                      await _handleLongPress(position);
                    },
                  ),

                  // Map clickable overlay when bottom sheet is expanded
                  if (_isBottomSheetOpen)
                    Positioned.fill(
                      child: PointerInterceptor(
                        child: GestureDetector(
                          onTap:
                              _toggleBottomSheet, // Collapse sheet when map is tapped
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),

                  // Long press detection overlay for mobile web (Google Maps doesn't support onLongPress on mobile web)
                  // Uses Listener to detect pointer events without blocking map gestures
                  if (kIsWeb &&
                      MobileDetectionService.isMobileDevice &&
                      !_isBottomSheetOpen &&
                      !_showFiltersDialog &&
                      _selectedSpot == null &&
                      !_showListPreview &&
                      _longPressedLocation == null)
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (PointerDownEvent event) {
                          // Reset handled flag for new press
                          _longPressHandled = false;

                          // Cancel any existing timer
                          _longPressTimer?.cancel();

                          // Store the start position
                          _longPressStartPosition = event.localPosition;

                          // Start a timer to detect long press (500ms)
                          _longPressTimer = Timer(
                            const Duration(milliseconds: 500),
                            () async {
                              if (_mapController == null ||
                                  _longPressStartPosition == null ||
                                  !mounted) {
                                return;
                              }

                              // Mark as handled IMMEDIATELY before any async operations
                              // This prevents onPointerUp from clearing it
                              _longPressHandled = true;

                              try {
                                // Get the visible region to calculate the LatLng from screen coordinates
                                final visibleRegion = await _mapController!
                                    .getVisibleRegion();

                                // Calculate the center of the visible region
                                final centerLat =
                                    (visibleRegion.northeast.latitude +
                                        visibleRegion.southwest.latitude) /
                                    2;
                                final centerLng =
                                    (visibleRegion.northeast.longitude +
                                        visibleRegion.southwest.longitude) /
                                    2;

                                // Get the screen size
                                if (!mounted) return;
                                final screenSize = MediaQuery.of(context).size;

                                // Calculate the offset from center (in pixels)
                                final offsetX =
                                    _longPressStartPosition!.dx -
                                    screenSize.width / 2;
                                final offsetY =
                                    _longPressStartPosition!.dy -
                                    screenSize.height / 2;

                                // Calculate the lat/lng range of the visible region
                                final latRange =
                                    visibleRegion.northeast.latitude -
                                    visibleRegion.southwest.latitude;
                                final lngRange =
                                    visibleRegion.northeast.longitude -
                                    visibleRegion.southwest.longitude;

                                // Convert pixel offset to lat/lng offset
                                // Note: Y is inverted (screen Y increases downward, but latitude increases upward)
                                final latOffset =
                                    -(offsetY / screenSize.height) * latRange;
                                final lngOffset =
                                    (offsetX / screenSize.width) * lngRange;

                                final longPressLatLng = LatLng(
                                  centerLat + latOffset,
                                  centerLng + lngOffset,
                                );

                                // Clear timer and position after marking as handled
                                _longPressTimer = null;
                                _longPressStartPosition = null;

                                await _handleLongPress(longPressLatLng);
                              } catch (e) {
                                debugPrint(
                                  'Error converting long press position: $e',
                                );
                                // Clear on error too
                                _longPressTimer = null;
                                _longPressStartPosition = null;
                                _longPressHandled = false;
                              }
                            },
                          );
                        },
                        onPointerUp: (PointerUpEvent event) {
                          // Only cancel if long press hasn't been handled yet
                          // Check the flag first (set synchronously in timer callback)
                          if (!_longPressHandled) {
                            _longPressTimer?.cancel();
                            _longPressTimer = null;
                            _longPressStartPosition = null;
                          }
                        },
                        onPointerCancel: (PointerCancelEvent event) {
                          // Only cancel if long press hasn't been handled yet
                          if (!_longPressHandled) {
                            _longPressTimer?.cancel();
                            _longPressTimer = null;
                            _longPressStartPosition = null;
                          }
                        },
                        onPointerMove: (PointerMoveEvent event) {
                          // Cancel long press if pointer moves significantly (user is panning)
                          // But only if it hasn't been handled yet
                          if (_longPressStartPosition != null &&
                              !_longPressHandled) {
                            final distance =
                                (event.localPosition - _longPressStartPosition!)
                                    .distance;
                            if (distance > 10) {
                              // 10 pixels threshold
                              _longPressTimer?.cancel();
                              _longPressTimer = null;
                              _longPressStartPosition = null;
                            }
                          }
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  // Top Search Bar
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: PointerInterceptor(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Autocomplete<Map<String, dynamic>>(
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) async {
                                      final query = textEditingValue.text
                                          .trim();
                                      if (query.isEmpty) {
                                        return const Iterable<
                                          Map<String, dynamic>
                                        >.empty();
                                      }
                                      if (_searchQuery != query) {
                                        setState(() => _searchQuery = query);
                                      }
                                      return _buildAutocompleteOptions(query);
                                    },
                                onSelected:
                                    (Map<String, dynamic> suggestion) async {
                                      await _selectAutocompleteOption(
                                        suggestion,
                                      );
                                    },
                                displayStringForOption:
                                    (Map<String, dynamic> option) {
                                      return option['description'] as String? ??
                                          '';
                                    },
                                fieldViewBuilder:
                                    (
                                      BuildContext context,
                                      TextEditingController
                                      textEditingController,
                                      FocusNode focusNode,
                                      VoidCallback onFieldSubmitted,
                                    ) {
                                      _autocompleteController =
                                          textEditingController;
                                      _autocompleteFocusNode = focusNode;
                                      if (!_hasSetInitialAutocompleteQuery &&
                                          widget.initialLocationQuery != null &&
                                          widget
                                              .initialLocationQuery!
                                              .isNotEmpty) {
                                        _hasSetInitialAutocompleteQuery = true;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted &&
                                                  textEditingController
                                                      .text
                                                      .isEmpty) {
                                                textEditingController.text =
                                                    widget
                                                        .initialLocationQuery!;
                                                setState(
                                                  () => _searchQuery = widget
                                                      .initialLocationQuery!,
                                                );
                                              }
                                            });
                                      }
                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      return TextField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          hintText: l10n.exploreSearchHint,
                                          prefixIcon: const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.search),
                                          ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_isSearchingLocation)
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              if (!_isSearchingLocation &&
                                                  textEditingController
                                                      .text
                                                      .isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  tooltip: l10n
                                                      .exploreClearSearchTooltip,
                                                  onPressed: () {
                                                    textEditingController
                                                        .clear();
                                                    setState(
                                                      () => _searchQuery = '',
                                                    );
                                                  },
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    IconButton(
                                                      icon: ReliableIcon(
                                                        icon: Icons.filter_list,
                                                        color:
                                                            _showFiltersDialog
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : null,
                                                      ),
                                                      tooltip: l10n
                                                          .exploreFiltersTooltip,
                                                      onPressed: () =>
                                                          _toggleFiltersDialog(),
                                                    ),
                                                    if (_hasActiveFilters())
                                                      Positioned(
                                                        right: 8,
                                                        top: 8,
                                                        child: Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                        ),
                                        onChanged: (value) {
                                          setState(() => _searchQuery = value);
                                        },
                                        onSubmitted: (_) {
                                          if (_hasAutocompleteOptions) {
                                            onFieldSubmitted();
                                          } else {
                                            _searchAndNavigateToLocation();
                                          }
                                        },
                                      );
                                    },
                                optionsViewBuilder:
                                    (
                                      BuildContext context,
                                      AutocompleteOnSelected<
                                        Map<String, dynamic>
                                      >
                                      onSelected,
                                      Iterable<Map<String, dynamic>> options,
                                    ) {
                                      final optionsList = options.toList();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(
                                                () => _hasAutocompleteOptions =
                                                    optionsList.isNotEmpty,
                                              );
                                            }
                                          });
                                      final highlightedIndex =
                                          AutocompleteHighlightedOption.of(
                                            context,
                                          );
                                      return _AutocompleteOverlayContent(
                                        optionsList: optionsList,
                                        currentSelection:
                                            highlightedIndex >= 0 &&
                                                highlightedIndex <
                                                    optionsList.length
                                            ? highlightedIndex
                                            : null,
                                        onSelected: onSelected,
                                      );
                                    },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Location Loading Indicator
                  if (_isGettingLocation)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 80,
                      right: 16,
                      child: PointerInterceptor(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.exploreFindingLocation,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Spot Detail Card (when marker is selected)
                  if (_selectedSpot != null && !_isBottomSheetOpen)
                    Positioned(
                      left: 16,
                      right: MediaQuery.of(context).size.width >= 600
                          ? null
                          : 16,
                      bottom: 16,
                      child: MediaQuery.of(context).size.width >= 600
                          ? SpotCard(
                              spot: _selectedSpot!,
                              variant: SpotCardVariant.overlay,
                              showCheckInPresence: true,
                              upcomingEventPin:
                                  _upcomingEventPinForSpot(_selectedSpot!),
                              maxWidth: 400,
                              spotListId:
                                  (_selectedSpot!.id != null &&
                                      _highlightedSpotIds.contains(
                                        _selectedSpot!.id,
                                      ))
                                  ? _selectedListId
                                  : null,
                              spotListName:
                                  (_selectedSpot!.id != null &&
                                      _highlightedSpotIds.contains(
                                        _selectedSpot!.id,
                                      ))
                                  ? _selectedListName
                                  : null,
                              onSpotListTap:
                                  (_selectedSpot!.id != null &&
                                      _highlightedSpotIds.contains(
                                        _selectedSpot!.id,
                                      ) &&
                                      _selectedListId != null)
                                  ? () => _openSpotListPreview(_selectedListId!)
                                  : null,
                              onTapWithImageIndex: (imageIndex) {
                                final baseUrl =
                                    UrlService.generateNavigationUrl(
                                      _selectedSpot!.id!,
                                      countryCode: _selectedSpot!.countryCode,
                                      city: _selectedSpot!.city,
                                    );
                                final navigationUrl = imageIndex > 0
                                    ? '$baseUrl?imageIndex=$imageIndex'
                                    : baseUrl;
                                context.push(navigationUrl);
                              },
                              onViewDetails: () {
                                final baseUrl =
                                    UrlService.generateNavigationUrl(
                                      _selectedSpot!.id!,
                                      countryCode: _selectedSpot!.countryCode,
                                      city: _selectedSpot!.city,
                                    );
                                // For onViewDetails, we don't have access to image index, so just use base URL
                                context.push(baseUrl);
                              },
                              onClose: () {
                                setState(() {
                                  _selectedSpot = null;
                                  _markers = _rebuildMarkers();
                                });
                              },
                            )
                          : Center(
                              child: SpotCard(
                                spot: _selectedSpot!,
                                variant: SpotCardVariant.overlay,
                                showCheckInPresence: true,
                                upcomingEventPin:
                                    _upcomingEventPinForSpot(_selectedSpot!),
                                maxWidth: double.infinity,
                                spotListId:
                                    (_selectedSpot!.id != null &&
                                        _highlightedSpotIds.contains(
                                          _selectedSpot!.id,
                                        ))
                                    ? _selectedListId
                                    : null,
                                spotListName:
                                    (_selectedSpot!.id != null &&
                                        _highlightedSpotIds.contains(
                                          _selectedSpot!.id,
                                        ))
                                    ? _selectedListName
                                    : null,
                                onSpotListTap:
                                    (_selectedSpot!.id != null &&
                                        _highlightedSpotIds.contains(
                                          _selectedSpot!.id,
                                        ) &&
                                        _selectedListId != null)
                                    ? () =>
                                          _openSpotListPreview(_selectedListId!)
                                    : null,
                                onTapWithImageIndex: (imageIndex) {
                                  final baseUrl =
                                      UrlService.generateNavigationUrl(
                                        _selectedSpot!.id!,
                                        countryCode: _selectedSpot!.countryCode,
                                        city: _selectedSpot!.city,
                                      );
                                  final navigationUrl = imageIndex > 0
                                      ? '$baseUrl?imageIndex=$imageIndex'
                                      : baseUrl;
                                  context.push(navigationUrl);
                                },
                                onViewDetails: () {
                                  final baseUrl =
                                      UrlService.generateNavigationUrl(
                                        _selectedSpot!.id!,
                                        countryCode: _selectedSpot!.countryCode,
                                        city: _selectedSpot!.city,
                                      );
                                  // For onViewDetails, we don't have access to image index, so just use base URL
                                  context.push(baseUrl);
                                },
                                onClose: () {
                                  setState(() {
                                    _selectedSpot = null;
                                    _markers = _rebuildMarkers();
                                  });
                                },
                              ),
                            ),
                    ),

                  // Spot List Preview Card (when chip is clicked)
                  if (_showListPreview &&
                      _selectedList != null &&
                      !_isBottomSheetOpen &&
                      _selectedSpot == null)
                    Positioned(
                      left: 16,
                      right: MediaQuery.of(context).size.width >= 600
                          ? null
                          : 16,
                      bottom: 16,
                      child: MediaQuery.of(context).size.width >= 600
                          ? _buildSpotListPreviewCard(maxWidth: 400)
                          : Center(
                              child: _buildSpotListPreviewCard(
                                maxWidth: double.infinity,
                              ),
                            ),
                    ),

                  // Add Spot Button (when long press is detected)
                  if (_longPressedLocation != null &&
                      _selectedSpot == null &&
                      !_showListPreview &&
                      !_showFiltersDialog)
                    Stack(
                      children: [
                        // Transparent overlay to dismiss on tap outside
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _longPressedLocation = null;
                                _longPressHandled = false;
                                // Rebuild markers to remove the long-pressed location marker
                                _markers = _rebuildMarkers();
                              });
                            },
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                        // The popup card
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: PointerInterceptor(
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  // Prevent tap from propagating to the overlay
                                },
                                child: Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.exploreAddSpotHereTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _longPressedLocation = null;
                                                  _longPressHandled = false;
                                                  // Rebuild markers to remove the long-pressed location marker
                                                  _markers = _rebuildMarkers();
                                                });
                                              },
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.profileCancel,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final location =
                                                    _longPressedLocation!;
                                                final addSpotUri = Uri(
                                                  path: '/explore',
                                                  queryParameters: {
                                                    'tab': 'add',
                                                    'lat': location.latitude
                                                        .toString(),
                                                    'lng': location.longitude
                                                        .toString(),
                                                  },
                                                );
                                                final authService =
                                                    Provider.of<AuthService>(
                                                      context,
                                                      listen: false,
                                                    );

                                                setState(() {
                                                  _longPressedLocation = null;
                                                  _longPressHandled = false;
                                                  // Rebuild markers to remove the long-pressed location marker
                                                  _markers = _rebuildMarkers();
                                                });

                                                // Require profile loaded before add spot (prevents email-as-createdByName)
                                                if (!authService
                                                    .isAuthenticated) {
                                                  context.go(
                                                    '/login?redirectTo=${Uri.encodeComponent(addSpotUri.toString())}',
                                                  );
                                                } else if (!authService
                                                    .isProfileReady) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        AppLocalizations.of(
                                                          context,
                                                        )!.exploreLoadingProfile,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  // Navigate to Add Spot tab (preserves bottom navigation).
                                                  context.go(
                                                    addSpotUri.toString(),
                                                  );
                                                }
                                              },
                                              icon: const ReliableIcon(
                                                icon: Icons.add_location,
                                              ),
                                              label: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.tabAddSpot,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Bottom Sheet with Spots List - hide when spot detail card, list preview, or add spot button is visible
                  if (_selectedSpot == null &&
                      !_showListPreview &&
                      _longPressedLocation == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: _bottomSheetAnimation,
                        builder: (context, child) {
                          return PointerInterceptor(
                            child: GestureDetector(
                              onTap: _isBottomSheetOpen
                                  ? null
                                  : _toggleBottomSheet, // Only clickable when collapsed
                              onPanStart:
                                  _handleDragStart, // Always enable drag gestures
                              onPanUpdate: _handleDragUpdate,
                              onPanEnd: _handleDragEnd,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1200,
                                  ),
                                  child: Container(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        _bottomSheetAnimation.value,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            8,
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              final l10n =
                                                  AppLocalizations.of(
                                                    context,
                                                  )!;
                                              return ExploreBottomSheetHeader(
                                                mode: _exploreListMode,
                                                spotsLabel: l10n
                                                    .exploreSpotCountShort(
                                                  _exploreSpotCountForHeader(),
                                                ),
                                                eventsLabel: l10n
                                                    .exploreEventCountShort(
                                                  _exploreEventCountForHeader(),
                                                ),
                                                spotsDetailSuffix:
                                                    _exploreSpotsSegmentSuffix(
                                                  l10n,
                                                ),
                                                eventsDetailSuffix:
                                                    _exploreEventsSegmentSuffix(
                                                  l10n,
                                                ),
                                                isSheetOpen:
                                                    _isBottomSheetOpen,
                                                onModeChanged: (mode) {
                                                  setState(() {
                                                    _exploreListMode = mode;
                                                  });
                                                },
                                                onToggleSheet:
                                                    _toggleBottomSheet,
                                              );
                                            },
                                          ),
                                        ),

                                        if (_isBottomSheetOpen)
                                          Expanded(
                                            child: _exploreListMode == 'events'
                                                ? (_visibleEvents.isEmpty
                                                    ? _buildExploreEventsEmptyState(
                                                        context,
                                                      )
                                                    : _buildEventsList())
                                                : (_visibleSpots.isEmpty
                                                ? Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          _searchQuery
                                                                  .isNotEmpty
                                                              ? Icons.search_off
                                                              : Icons
                                                                    .location_off,
                                                          size: 64,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        Text(
                                                          _searchQuery
                                                                  .isNotEmpty
                                                              ? AppLocalizations.of(
                                                                  context,
                                                                )!.exploreNoSpotsSearch
                                                              : AppLocalizations.of(
                                                                  context,
                                                                )!.exploreNoSpotsArea,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .headlineSmall,
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          _searchQuery
                                                                  .isNotEmpty
                                                              ? AppLocalizations.of(
                                                                  context,
                                                                )!.exploreNoSpotsSearchHint
                                                              : AppLocalizations.of(
                                                                  context,
                                                                )!.exploreNoSpotsMapHint,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withValues(
                                                                          alpha:
                                                                              0.7,
                                                                        ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : _buildSpotsList()),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Spot List Chip - Shows when spots are highlighted from a list
                  if (_selectedListName != null &&
                      _highlightedSpotIds.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final rightPosition = screenWidth > 1200
                            ? (screenWidth - 1200) / 2 + 16
                            : 16.0;
                        return Positioned(
                          top:
                              MediaQuery.of(context).padding.top +
                              16 +
                              64 +
                              8, // Below search bar (16 top padding + 16 margin + ~64 search bar height + 8 spacing)
                          right: rightPosition,
                          child: PointerInterceptor(
                            child: InkWell(
                              onTap: _selectedList != null
                                  ? () async {
                                      // Show spot list preview card
                                      // Collapse bottom sheet if open
                                      if (_isBottomSheetOpen) {
                                        _toggleBottomSheet();
                                      }
                                      setState(() {
                                        _showListPreview = true;
                                        // Close spot detail if open
                                        _selectedSpot = null;
                                      });
                                      // Fit map to show all spots in the list
                                      if (_selectedList != null &&
                                          _selectedList!
                                              .effectiveSpotIds
                                              .isNotEmpty) {
                                        await _fitMapToSpotList(
                                          _selectedList!.effectiveSpotIds,
                                        );
                                      }
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Chip(
                                label: Text(_selectedListName!),
                                avatar: Icon(Icons.list, size: 18),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                elevation: 2,
                                onDeleted: () {
                                  _clearSpotListSelection();
                                  // Clear from SearchStateService
                                  final searchState =
                                      Provider.of<SearchStateService>(
                                        context,
                                        listen: false,
                                      );
                                  searchState.setSelectedListId(null);
                                },
                                deleteIcon: Icon(Icons.close, size: 18),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Refresh Spots Button - Floating Action Button
                  if (!_isBottomSheetOpen &&
                      _selectedSpot == null &&
                      !_showListPreview)
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final rightPosition = screenWidth > 1200
                            ? (screenWidth - 1200) / 2 + 16
                            : 16.0;
                        return Positioned(
                          right: rightPosition,
                          bottom:
                              MediaQuery.of(context).size.height * 0.09 +
                              144, // Position above map/satellite button
                          child: PointerInterceptor(
                            child: FloatingActionButton(
                              onPressed: _isLoadingMapData
                                  ? null
                                  : () {
                                      _loadMapDataForCurrentView();
                                    },
                              heroTag: 'refreshSpotsFab',
                              mini: true,
                              tooltip: AppLocalizations.of(
                                context,
                              )!.exploreRefreshMapTooltip,
                              child: _isLoadingMapData
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const ReliableIcon(icon: Icons.refresh),
                            ),
                          ),
                        );
                      },
                    ),

                  // Map Type Toggle Button - Floating Action Button
                  if (!_isBottomSheetOpen &&
                      _selectedSpot == null &&
                      !_showListPreview)
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final rightPosition = screenWidth > 1200
                            ? (screenWidth - 1200) / 2 + 16
                            : 16.0;
                        return Positioned(
                          right: rightPosition,
                          bottom:
                              MediaQuery.of(context).size.height * 0.09 +
                              80, // Position above location button
                          child: PointerInterceptor(
                            child: FloatingActionButton(
                              onPressed: () {
                                setState(() {
                                  _isSatelliteView = !_isSatelliteView;
                                });
                                final searchState =
                                    Provider.of<SearchStateService>(
                                      context,
                                      listen: false,
                                    );
                                searchState.setSatellite(_isSatelliteView);
                              },
                              heroTag: 'mapTypeToggleFab',
                              mini: true,
                              tooltip: _isSatelliteView
                                  ? AppLocalizations.of(
                                      context,
                                    )!.exploreSwitchToMap
                                  : AppLocalizations.of(
                                      context,
                                    )!.exploreSwitchToSatellite,
                              child: ReliableIcon(
                                icon: _isSatelliteView
                                    ? Icons.map
                                    : Icons.terrain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Location Button - Floating Action Button (only show when bottom sheet is collapsed and no spot selected)
                  if (!_isBottomSheetOpen &&
                      _selectedSpot == null &&
                      !_showListPreview)
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final rightPosition = screenWidth > 1200
                            ? (screenWidth - 1200) / 2 + 16
                            : 16.0;
                        return Positioned(
                          right: rightPosition,
                          bottom:
                              MediaQuery.of(context).size.height * 0.09 +
                              16, // Position above bottom sheet
                          child: PointerInterceptor(
                            child: FloatingActionButton(
                              onPressed: _getCurrentLocation,
                              heroTag: 'currentLocationFab',
                              mini: true,
                              tooltip: _isLocationPermissionDenied
                                  ? AppLocalizations.of(
                                      context,
                                    )!.exploreLocationPermissionDenied
                                  : AppLocalizations.of(
                                      context,
                                    )!.exploreCenterOnMyLocation,
                              child: _isGettingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      _isLocationPermissionDenied
                                          ? Icons.location_disabled
                                          : Icons.my_location,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          // Filters Dialog
          if (_showFiltersDialog) _buildFiltersDialog(),
        ],
      ),
    );
  }

  Widget _buildFiltersDialog() {
    return GestureDetector(
      onTap: () {
        // Close dialog when tapping outside
        setState(() {
          _showFiltersDialog = false;
        });
      },
      child: PointerInterceptor(
        // Intercept pointer events on the full-screen barrier area
        child: Container(
          color: Colors.black.withValues(
            alpha: 0.5,
          ), // Semi-transparent background
          child: Center(
            child: PointerInterceptor(
              child: GestureDetector(
                onTap: () {
                  // Prevent dialog from closing when tapping inside
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1200),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.exploreFiltersDialogTitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showFiltersDialog = false;
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),

                        // Filters Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildFilters(),
                          ),
                        ),

                        // Clear and Apply Buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () async {
                                    final searchState =
                                        Provider.of<SearchStateService>(
                                          context,
                                          listen: false,
                                        );
                                    await searchState.clearAllFilters();
                                    if (!mounted) return;
                                    setState(() {
                                      _showFiltersDialog = false;
                                    });
                                  },
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.exploreClearFilters,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showFiltersDialog = false;
                                    });
                                    // Reload spots since source filtering is done at database level
                                    _loadMapDataForCurrentView();
                                  },
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.exploreApplyFilters,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
