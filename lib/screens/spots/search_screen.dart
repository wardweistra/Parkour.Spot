import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, listEquals;
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:uuid/uuid.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../services/event_map_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/spot_service.dart';
import '../../models/event_map_pin.dart';
import '../../utils/explore_events_utils.dart';
import '../../widgets/event_card.dart';
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
import '../../widgets/custom_button.dart';
import '../../widgets/spot_card.dart';
import '../../widgets/linked_upcoming_event_panel.dart';
import '../../widgets/source_details_dialog.dart';
import '../../config/app_config.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/map_bounds_utils.dart';
import '../../utils/map_camera_utils.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/upcoming_linked_events_utils.dart';
import '../../utils/explore_search_autocomplete.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../constants/spot_attributes.dart';
import '../../l10n/app_localizations.dart';

/// Stateful overlay for autocomplete suggestions; manages ScrollController lifecycle.
class _AutocompleteOverlayContent extends StatefulWidget {
  final List<Map<String, dynamic>> optionsList;
  final int? currentSelection;
  final void Function(Map<String, dynamic>) onSelected;
  final bool isLoading;

  const _AutocompleteOverlayContent({
    required this.optionsList,
    required this.currentSelection,
    required this.onSelected,
    this.isLoading = false,
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

    return TextFieldTapRegion(
      child: PointerInterceptor(
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(4),
              shrinkWrap: true,
              itemCount: optionsList.length + (widget.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= optionsList.length) {
                  return const ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final option = optionsList[index];
                final optionType = option['optionType'] as String? ?? 'place';
                final isSpotSuggestion = optionType == 'spot';
                final isEventSuggestion = optionType == 'event';
                final description = option['description'] as String? ?? '';
                final secondary = option['secondary'] as String?;
                final isSelected = currentSelection == index;
                final colorScheme = Theme.of(context).colorScheme;
                final leadingIcon = isSpotSuggestion
                    ? (isSelected ? Icons.place : Icons.place_outlined)
                    : isEventSuggestion
                    ? (isSelected ? Icons.event : Icons.event_outlined)
                    : (isSelected ? Icons.public : Icons.public_outlined);

                return ListTile(
                  leading: Icon(leadingIcon, color: colorScheme.primary),
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  selected: isSelected,
                  selectedTileColor: colorScheme.primary.withValues(
                    alpha: 0.15,
                  ),
                  title: Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isSelected
                        ? TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
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
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                )
                              : null,
                        )
                      : null,
                  onTap: () => widget.onSelected(option),
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

/// Selected explore pins stack above latitude-ordered pins but below overlays.
const int _exploreSelectedMarkerZBase = 8000;

class _PendingExploreMarker {
  const _PendingExploreMarker({
    required this.latitude,
    required this.isSelected,
    required this.build,
  });

  final double latitude;
  final bool isSelected;
  final Marker Function(int zIndex) build;
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

  /// Floor for the collapsed sheet so header chrome (logo, mode pills, chevron)
  /// always fits; 9% of short web viewports can dip below content height.
  static const double _collapsedBottomSheetMinHeight = 80;

  static const double _collapsedBottomSheetHeightFraction = 0.09;
  static const double _expandedBottomSheetHeightFraction = 0.75;
  Position? _currentPosition;
  BitmapDescriptor? _userLocationIcon;
  BitmapDescriptor? _spotDefaultIcon;
  BitmapDescriptor? _spotSelectedIcon;
  BitmapDescriptor? _spotHighlightedIcon;
  BitmapDescriptor? _spotSelectedHighlightedIcon;
  BitmapDescriptor? _addSpotPinIcon;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final ExploreAutocompleteSession _autocompleteSession;
  String _searchQuery = '';
  String? _placesSessionToken;
  List<Spot> _visibleSpots = [];
  List<Spot> _loadedSpots = []; // Spots loaded for the current map view
  Set<Marker> _markers = {};
  Spot? _selectedSpot;
  EventMapPin? _selectedEventPin;
  bool _isLoadingSpotsForView =
      false; // Loading state for spots within current view
  bool _isSearchingLocation = false; // Loading state for location search
  int? _totalSpotsInView; // Total unfiltered spots in current bounds
  int? _bestShownCount; // Number of ranked spots returned (up to 100)
  List<EventMapPin> _loadedEventPins = [];
  List<EventMapPin> _visibleEvents = [];
  Map<String, EventMapPin> _eventPinBySpotId = {};
  bool _isLoadingEventsForView = false;
  String _exploreListMode = 'spots';
  BitmapDescriptor? _eventIcon;
  BitmapDescriptor? _eventSelectedIcon;
  late AnimationController _bottomSheetAnimationController;
  late CurvedAnimation _bottomSheetAnimation;
  late PageController _imagePageController;
  double _dragStartY = 0.0;
  bool _isDragging = false;
  double _lastKnownZoom = 14.0;
  // Filters
  bool _hasImagesOnly = false;
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
  String? _eventIdToLocate; // Event ID to locate from query parameter
  String? _locateSpotInFlight; // Prevents overlapping locate-by-id work
  Timer? _locationPollingTimer; // Timer for polling user location periodically
  // Spot list highlighting
  String? _selectedListId; // Currently selected spot list ID
  String? _selectedListName; // Name of the selected spot list
  SpotList? _selectedList; // Full spot list object for preview
  bool _showListPreview = false; // Whether to show the list preview card
  Future<LinkedSpotEvents>? _linkedSpotListEventsFuture;
  Set<String> _highlightedSpotIds = {}; // Spot IDs from selected list
  DateTime? _lastAutocompleteSpotSelection; // Guard against mobile tap-through

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
    final newHasImagesOnly = searchState.hasImagesOnly;
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
        _hasImagesOnly != newHasImagesOnly ||
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
      _hasImagesOnly = newHasImagesOnly;
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
          _linkedSpotListEventsFuture = null;
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
      return _hasImagesOnly ||
          _spotAccess.isNotEmpty ||
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
    _autocompleteSession = ExploreAutocompleteSession(
      config: const ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsAndEvents,
      ),
      fetchPlaces: ({required query, sessionToken, mapCenter}) {
        return Provider.of<GeocodingService>(
          context,
          listen: false,
        ).placesAutocomplete(
          input: query,
          sessionToken: sessionToken,
          biasLat: mapCenter?.latitude,
          biasLng: mapCenter?.longitude,
          radiusMeters: 50000,
        );
      },
      fetchSpots: ({required query}) {
        return Provider.of<SpotService>(
          context,
          listen: false,
        ).searchSpotsByTitle(query: query, limit: 6);
      },
      fetchEvents: ({required query}) {
        return Provider.of<AdminEventsService>(
          context,
          listen: false,
        ).searchEventsByTitle(query: query, limit: 6);
      },
      mapCenterProvider: _mapCenterFromSearchState,
      placesSessionTokenProvider: () {
        _placesSessionToken ??= const Uuid().v4();
        return _placesSessionToken;
      },
    );
    _autocompleteSession.addListener(_onAutocompleteSessionChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    if (widget.initialLocationQuery != null &&
        widget.initialLocationQuery!.isNotEmpty) {
      _searchQuery = widget.initialLocationQuery!;
      _searchController.text = widget.initialLocationQuery!;
    }
    _searchController.addListener(_onSearchChanged);

    // Check permission status on initialization to show correct icon
    _checkLocationPermission();

    // Set initial list ID - prioritize URL parameter, then fall back to stored value
    // Will be set from SearchStateService in post-frame callback if not provided via URL

    _loadUserLocationIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSpotIcons();
      }
    });

    // Initialize bottom sheet animation (0 = collapsed, 1 = expanded).
    // Absolute heights are resolved at layout time so collapsed keeps a min size.
    _bottomSheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetAnimationController,
      curve: Curves.easeInOut,
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
        _hasImagesOnly = _searchStateServiceRef!.hasImagesOnly;
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

      unawaited(
        warmupExploreAutocomplete(
          geocoding: Provider.of<GeocodingService>(context, listen: false),
          spotService: _spotServiceRef!,
          eventsService: Provider.of<AdminEventsService>(
            context,
            listen: false,
          ),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for locateSpotId / locateEventId query parameters (only if not already set)
    if (_spotIdToLocate == null || _eventIdToLocate == null) {
      try {
        final routerState = GoRouterState.of(context);
        if (_spotIdToLocate == null) {
          final locateSpotId = routerState.uri.queryParameters['locateSpotId'];
          if (locateSpotId != null && locateSpotId.isNotEmpty) {
            _spotIdToLocate = locateSpotId;
          }
        }
        if (_eventIdToLocate == null) {
          final locateEventId =
              routerState.uri.queryParameters['locateEventId'];
          if (locateEventId != null && locateEventId.isNotEmpty) {
            _eventIdToLocate = locateEventId;
          }
        }
      } catch (e) {
        // Ignore errors when accessing router state
      }
    }
  }

  /// Called when the map tab becomes visible. Processes locateSpotId/locateEventId/listId from
  /// the URL and refreshes map tiles (fixes "one tile" issue when map was built off-screen).
  void onMapTabActivated() {
    if (!mounted) return;

    String? locateSpotId;
    String? locateEventId;
    String? listIdFromUrl;
    try {
      final state = GoRouterState.of(context);
      locateSpotId = state.uri.queryParameters['locateSpotId'];
      locateEventId = state.uri.queryParameters['locateEventId'];
      listIdFromUrl = state.uri.queryParameters['listId'];
    } catch (_) {}

    final listId = listIdFromUrl ?? widget.initialListId;
    final hasFocusIntent =
        (locateSpotId != null && locateSpotId.isNotEmpty) ||
        (locateEventId != null && locateEventId.isNotEmpty) ||
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

    if (locateEventId != null && locateEventId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _locateEventById(locateEventId!);
      });
    }
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    _longPressTimer?.cancel();
    _locationPollingTimer?.cancel();
    _mapController = null;
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _autocompleteSession.removeListener(_onAutocompleteSessionChanged);
    _autocompleteSession.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bottomSheetAnimation.dispose();
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
    if (_searchFocusNode.hasFocus) {
      _autocompleteSession.onQueryChanged(_searchController.text);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _autocompleteSession.onQueryChanged(query);
      }
    } else {
      _autocompleteSession.clear();
    }
    if (mounted) setState(() {});
  }

  void _onAutocompleteSessionChanged() {
    if (mounted) setState(() {});
  }

  LatLng? _mapCenterFromSearchState() {
    final lat = _searchStateServiceRef?.centerLat;
    final lng = _searchStateServiceRef?.centerLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _toggleFiltersDialog() {
    final shouldOpen = !_showFiltersDialog;
    if (shouldOpen) {
      // Collapse suggestions before showing filters.
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
      _autocompleteSession.clear();
    }
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
      final controllerToUpdate = _searchController;
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
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
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

  Future<void> _selectSpotSuggestion(Map<String, dynamic> suggestion) async {
    final spot = suggestion['spot'];
    if (spot is! Spot) return;

    final controllerToUpdate = _searchController;
    final newText = spot.name;
    setState(() {
      controllerToUpdate.text = newText;
      controllerToUpdate.selection = TextSelection.fromPosition(
        TextPosition(offset: controllerToUpdate.text.length),
      );
      _searchQuery = newText;
      _isSearchingLocation = false;
    });

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    _lastAutocompleteSpotSelection = DateTime.now();
    await _locateSpot(spot);
    if (spot.id != null) {
      _loadFullSpotInBackground(spot.id!);
    }
  }

  Future<void> _selectEventSuggestion(Map<String, dynamic> suggestion) async {
    final eventId = suggestion['eventId'] as String?;
    if (eventId == null || eventId.isEmpty) return;

    final description = suggestion['description'] as String? ?? '';
    final controllerToUpdate = _searchController;
    setState(() {
      controllerToUpdate.text = description;
      controllerToUpdate.selection = TextSelection.fromPosition(
        TextPosition(offset: controllerToUpdate.text.length),
      );
      _searchQuery = description;
      _isSearchingLocation = false;
    });

    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    _lastAutocompleteSpotSelection = DateTime.now();
    await _locateEventById(eventId);
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
    if (optionType == 'event') {
      await _selectEventSuggestion(option);
      return;
    }
    await _selectPlaceSuggestion(option);
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

      final center = _mapCenterFromSearchState();

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
    if (_mapController == null || !mounted) {
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
          hasImages:
              (_filterArea ?? 'amenities') == 'amenities' && _hasImagesOnly,
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
      _eventPinBySpotId = eventPinsBySpotId(_loadedEventPins);
      _visibleEvents = dedupePinsByEventId(_loadedEventPins);

      if (!mounted) return;
      _updateVisibleSpots();
    } catch (e) {
      if (!mounted) return;
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
    if (!mounted) return;
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
    // Full width keeps tabs left-aligned while Sources is still loading
    // (otherwise the column shrink-wraps and the scroll view centers it).
    return SizedBox(
      width: double.infinity,
      child: Column(
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
      ),
    );
  }

  Widget _buildAmenitiesFilters() {
    return Consumer<SearchStateService>(
      builder: (context, searchState, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotosFilterCard(searchState),
            const SizedBox(height: 12),
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

  Widget _buildPhotosFilterCard(SearchStateService searchState) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exploreSpotPhotosTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.exploreFilterHasImages),
              value: _hasImagesOnly,
              onChanged: (value) {
                searchState.setHasImagesOnly(value);
                setState(() => _hasImagesOnly = value);
                if (_mapController != null) {
                  _loadMapDataForCurrentView();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessFilterCard(SearchStateService searchState) {
    final l10n = AppLocalizations.of(context)!;
    final keys = SpotAttributes.getKeys('access');
    final scheme = Theme.of(context).colorScheme;
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keys.map((key) {
                final label = SpotAttributes.getLabel('access', key);
                final icon = SpotAttributes.getIcon('access', key);
                final description = SpotAttributes.getFilterDescription(
                  'access',
                  key,
                );
                final selected = _spotAccess.contains(key);
                Color? selectedColor;
                Color? selectedForeground;
                switch (key) {
                  case 'public':
                    selectedColor = Colors.green.withValues(alpha: 0.18);
                    selectedForeground = Colors.green.shade800;
                    break;
                  case 'restricted':
                    selectedColor = Colors.orange.withValues(alpha: 0.18);
                    selectedForeground = Colors.orange.shade800;
                    break;
                  case 'paid':
                    selectedColor = Colors.blue.withValues(alpha: 0.18);
                    selectedForeground = Colors.blue.shade800;
                    break;
                  default:
                    selectedColor = scheme.primaryContainer;
                    selectedForeground = scheme.onPrimaryContainer;
                }
                return _buildExploreFilterChip(
                  label: label,
                  icon: icon,
                  tooltip: description,
                  selected: selected,
                  selectedColor: selectedColor,
                  selectedForeground: selectedForeground,
                  onSelected: (_) {
                    searchState.toggleSpotAccess(key);
                    setState(() {
                      if (selected) {
                        _spotAccess = List<String>.from(_spotAccess)
                          ..remove(key);
                      } else {
                        _spotAccess = List<String>.from(_spotAccess)..add(key);
                      }
                    });
                    if (_mapController != null) {
                      _loadMapDataForCurrentView();
                    }
                  },
                );
              }).toList(),
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
              l10n.exploreFacilitiesMatchAllHint,
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
                final description = SpotAttributes.getFilterDescription(
                  'facilities',
                  key,
                );
                final selected = getFacility(key);
                return _buildExploreFilterChip(
                  label: label,
                  icon: icon,
                  tooltip: description,
                  selected: selected,
                  onSelected: (value) => setFacility(key, value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared FilterChip styling for Explore amenity filters (matches Sources).
  Widget _buildExploreFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
    String? tooltip,
    Color? selectedColor,
    Color? selectedForeground,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selectedBg = selectedColor ?? scheme.primaryContainer;
    final selectedFg = selectedForeground ?? scheme.onPrimaryContainer;
    return FilterChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 18, color: selected ? selectedFg : null),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      tooltip: tooltip,
      showCheckmark: icon == null,
      selectedColor: selectedBg,
      checkmarkColor: selectedFg,
      labelStyle: TextStyle(color: selected ? selectedFg : null),
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
            const SizedBox(height: 8),
            Text(
              l10n.exploreAttributesMatchAnyHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            if (_attributeFilterMode == 'spotFeatures')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SpotAttributes.getKeys('features').map((key) {
                  final label = SpotAttributes.getLabel('features', key);
                  final icon = SpotAttributes.getIcon('features', key);
                  final description = SpotAttributes.getFilterDescription(
                    'features',
                    key,
                  );
                  final selected = _spotFeatures.contains(key);
                  return _buildExploreFilterChip(
                    label: label,
                    icon: icon,
                    tooltip: description,
                    selected: selected,
                    onSelected: (_) {
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
                      if (_mapController != null) {
                        _loadMapDataForCurrentView();
                      }
                    },
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
                  final description = SpotAttributes.getFilterDescription(
                    'goodFor',
                    key,
                  );
                  final selected = _goodFor.contains(key);
                  return _buildExploreFilterChip(
                    label: label,
                    icon: icon,
                    tooltip: description,
                    selected: selected,
                    onSelected: (_) {
                      searchState.toggleGoodFor(key);
                      setState(() {
                        if (selected) {
                          _goodFor = List<String>.from(_goodFor)..remove(key);
                        } else {
                          _goodFor = List<String>.from(_goodFor)..add(key);
                        }
                      });
                      if (_mapController != null) {
                        _loadMapDataForCurrentView();
                      }
                    },
                  );
                }).toList(),
              ),
          ],
        ),
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
    final pending = <_PendingExploreMarker>[];

    for (final spot in _visibleSpots) {
      final bool isSelected = _selectedSpot?.id != null
          ? _selectedSpot!.id == spot.id
          : _selectedSpot?.name == spot.name;
      final bool isHighlighted =
          spot.id != null && _highlightedSpotIds.contains(spot.id);
      final eventPin = spot.id != null ? _eventPinBySpotId[spot.id!] : null;
      final bool hasEvent = eventPin != null;

      BitmapDescriptor icon;
      if (hasEvent && !isSelected && !isHighlighted) {
        icon = _eventIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isSelected && isHighlighted) {
        icon = _spotSelectedHighlightedIcon ?? BitmapDescriptor.defaultMarker;
      } else if (isSelected && hasEvent) {
        icon = _eventSelectedIcon ?? BitmapDescriptor.defaultMarker;
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

      pending.add(
        _PendingExploreMarker(
          latitude: spot.latitude,
          isSelected: isSelected,
          build: (zIndex) => Marker(
            markerId: MarkerId(spot.id ?? spot.name),
            position: LatLng(spot.latitude, spot.longitude),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: zIndex,
            onTap: () {
              if (_isBottomSheetOpen || _showFiltersDialog) return;
              setState(() {
                _selectedSpot = spot;
                _selectedEventPin = null;
                _showListPreview = false;
                _markers = _rebuildMarkers();
              });
            },
          ),
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
      final isSelected = _selectedEventPin?.id == pin.id;
      final icon =
          (isSelected ? (_eventSelectedIcon ?? _eventIcon) : _eventIcon) ??
          BitmapDescriptor.defaultMarker;

      pending.add(
        _PendingExploreMarker(
          latitude: pin.latitude,
          isSelected: isSelected,
          build: (zIndex) => Marker(
            markerId: MarkerId(markerId),
            position: LatLng(pin.latitude, pin.longitude),
            icon: icon,
            anchor: const Offset(0.5, 1.0),
            zIndexInt: zIndex,
            onTap: () {
              if (_isBottomSheetOpen || _showFiltersDialog) return;
              _selectEventPin(pin, focusMap: false);
            },
          ),
        ),
      );
    }

    final ordered = MarkerIconUtils.sortByLatitudeNorthFirst(
      pending,
      (item) => item.latitude,
    );
    for (var i = 0; i < ordered.length; i++) {
      final item = ordered[i];
      final zIndex = item.isSelected ? _exploreSelectedMarkerZBase + i : i;
      markers.add(item.build(zIndex));
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
      final BitmapDescriptor eventPin = await MarkerIconUtils.loadEventMapPin(
        logicalHeight: browsePinHeight,
      );
      final BitmapDescriptor eventSelectedPin =
          await MarkerIconUtils.loadEventSelectedMapPin(
            logicalHeight: browsePinHeight,
          );
      if (mounted) {
        setState(() {
          _spotDefaultIcon = normalPin;
          _spotSelectedIcon = normalSelectedPin;
          _spotHighlightedIcon = listPin;
          _spotSelectedHighlightedIcon = listSelectedPin;
          _addSpotPinIcon = addPin;
          _eventIcon = eventPin;
          _eventSelectedIcon = eventSelectedPin;
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
          _linkedSpotListEventsFuture = null;
          _highlightedSpotIds.clear();
          _markers = _rebuildMarkers();
        });

        if (_selectedListId == listId) {
          _searchStateServiceRef?.setSelectedListId(null);
        }
        return;
      }

      final eventsService = Provider.of<AdminEventsService>(
        context,
        listen: false,
      );
      final linkedEventsFuture = eventsService
          .getEventsForSpotList(listId)
          .then(
            (events) => partitionLinkedEvents(
              upcomingLinkedEventsFromParkourEvents(events),
            ),
          );

      setState(() {
        _selectedList = list;
        _selectedListName = list.name;
        _linkedSpotListEventsFuture = linkedEventsFuture;
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
      // Close spot/event detail if open
      _selectedSpot = null;
      _selectedEventPin = null;
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
      _linkedSpotListEventsFuture = null;
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
      // Clear selected spot/event when opening bottom sheet
      if (_isBottomSheetOpen) {
        _selectedSpot = null;
        _selectedEventPin = null;
      }
    });
  }

  double _collapsedBottomSheetHeight(double screenHeight) {
    return math.max(
      screenHeight * _collapsedBottomSheetHeightFraction,
      _collapsedBottomSheetMinHeight,
    );
  }

  double _bottomSheetHeight(double screenHeight, double t) {
    final collapsed = _collapsedBottomSheetHeight(screenHeight);
    final expanded = screenHeight * _expandedBottomSheetHeightFraction;
    return lerpDouble(collapsed, expanded, t)!;
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

  // Public API to check if event detail card is open
  bool get isEventDetailOpen => _selectedEventPin != null;

  // Public API so parent can close event detail if open
  void closeEventDetail() {
    if (_selectedEventPin != null) {
      setState(() {
        _selectedEventPin = null;
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
      if (mounted) {
        _loadMapDataForCurrentView();
      }
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
    final viewport = MediaQuery.sizeOf(context);

    // Collapse bottom sheet if open
    if (_isBottomSheetOpen) {
      await _bottomSheetAnimationController.reverse();
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    }

    // Focus the spot with fluid zoom-in (no zoom-out). On small screens, the
    // final pixel scroll keeps the marker visible above the detail card.
    if (_mapController != null) {
      final updates = selectedSpotCameraUpdates(
        target: LatLng(spot.latitude, spot.longitude),
        currentZoom: _lastKnownZoom,
        viewportWidth: viewport.width,
        viewportHeight: viewport.height,
      );
      for (final update in updates) {
        await _mapController!.animateCamera(update);
      }
    }

    // Select the spot and refresh markers to show detail card overlay
    if (mounted) {
      setState(() {
        _selectedSpot = spot;
        _selectedEventPin = null;
        _markers = _rebuildMarkers();
      });
    }
  }

  Future<void> _selectEventPin(EventMapPin pin, {bool focusMap = true}) async {
    if (_isBottomSheetOpen) {
      await _bottomSheetAnimationController.reverse();
      if (mounted) {
        setState(() {
          _isBottomSheetOpen = false;
        });
      }
    }

    if (focusMap && _mapController != null) {
      const double desiredZoom = 15.0;
      final double targetZoom = _lastKnownZoom < desiredZoom
          ? desiredZoom
          : _lastKnownZoom;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
      );
      if (_lastKnownZoom < targetZoom) {
        await _mapController!.animateCamera(CameraUpdate.zoomTo(targetZoom));
      }
    }

    if (mounted) {
      setState(() {
        _selectedEventPin = pin;
        _selectedSpot = null;
        _showListPreview = false;
        _markers = _rebuildMarkers();
      });
    }
  }

  Future<void> _locateSpotById(String spotId) async {
    if (_locateSpotInFlight == spotId) return;
    _locateSpotInFlight = spotId;

    // Wait for spot service to be available
    _spotServiceRef ??= Provider.of<SpotService>(context, listen: false);

    if (_spotServiceRef == null) {
      _locateSpotInFlight = null;
      return;
    }

    try {
      final spot = await _spotServiceRef!.getSpotById(spotId);
      if (spot != null && mounted) {
        await _locateSpot(spot);
        // Clear the query parameter from URL after successful location
        if (mounted &&
            GoRouterState.of(context).uri.queryParameters['locateSpotId'] !=
                null) {
          context.go('/explore');
        }
      }
    } catch (e) {
      // Ignore errors - spot might not be found or service not ready
      if (mounted) {
        debugPrint('Failed to locate spot $spotId: $e');
      }
    } finally {
      if (_locateSpotInFlight == spotId) {
        _locateSpotInFlight = null;
      }
    }
  }

  Future<void> _locateEventById(String eventId) async {
    try {
      final admin = Provider.of<AdminEventsService>(context, listen: false);
      final event = await admin.getEventById(eventId);
      if (event == null || !mounted) return;

      final eventMapService = Provider.of<EventMapService>(
        context,
        listen: false,
      );
      final target = await eventMapService.resolveLocateTargetForEvent(event);
      if (target == null || !mounted) return;

      if (target.isSpotList) {
        await _locateSpotListById(target.spotListId!);
        if (mounted) {
          context.go('/explore');
        }
        return;
      }

      final pin = target.pin!;
      EventMapPin? loadedPin;
      for (final candidate in _loadedEventPins) {
        if (candidate.eventId == eventId) {
          loadedPin = candidate;
          break;
        }
      }

      await _selectEventPin(loadedPin ?? pin, focusMap: true);
      if (mounted) {
        context.go('/explore');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Failed to locate event $eventId: $e');
      }
    }
  }

  Future<void> _locateSpotListById(String listId) async {
    _searchStateServiceRef?.setSelectedListId(listId);
    if (mounted) {
      setState(() => _selectedListId = listId);
    }
    await _openSpotListPreview(listId);
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

  Future<void> _locateEvent(EventMapPin pin) async {
    final admin = Provider.of<AdminEventsService>(context, listen: false);
    final event = await admin.getEventById(pin.eventId);
    if (event == null || !mounted) return;

    final target = await Provider.of<EventMapService>(
      context,
      listen: false,
    ).resolveLocateTargetForEvent(event);
    if (target == null || !mounted) return;

    if (target.isSpotList) {
      await _locateSpotListById(target.spotListId!);
      return;
    }

    await _selectEventPin(target.pin ?? pin, focusMap: true);
  }

  Widget _buildEventOverlayCard({required double maxWidth}) {
    final pin = _selectedEventPin!;
    return EventCard(
      pin: pin,
      variant: EventCardVariant.overlay,
      maxWidth: maxWidth,
      onTapWithImageIndex: (imageIndex) {
        final path = '/event/${pin.eventId}';
        final navigationUrl = imageIndex > 0
            ? '$path?imageIndex=$imageIndex'
            : path;
        context.push(navigationUrl);
      },
      onClose: () {
        setState(() {
          _selectedEventPin = null;
          _markers = _rebuildMarkers();
        });
      },
    );
  }

  Widget _buildEventCard(EventMapPin pin) {
    return EventCard(
      pin: pin,
      onTapWithImageIndex: (imageIndex) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
        );
        final path = '/event/${pin.eventId}';
        final navigationUrl = imageIndex > 0
            ? '$path?imageIndex=$imageIndex'
            : path;
        context.push(navigationUrl);
      },
      onLocate: () => _locateEvent(pin),
    );
  }

  Widget _buildEventsList() {
    final groups = groupExploreEventsByMonth(_visibleEvents);
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600;

    if (useGrid) {
      const maxCrossAxisExtent = 480.0;
      const mainAxisExtent = 440.0;

      return CustomScrollView(
        slivers: [
          for (var i = 0; i < groups.length; i++) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, i == 0 ? 16 : 0, 16, 0),
                child: _ExploreEventMonthHeader(
                  monthStart: groups[i].monthStart,
                  isFirst: i == 0,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxCrossAxisExtent,
                  mainAxisExtent: mainAxisExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildEventCard(groups[i].events[index]),
                  childCount: groups[i].events.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      );
    }

    final entries =
        <
          ({
            bool isHeader,
            DateTime? monthStart,
            bool isFirst,
            EventMapPin? pin,
          })
        >[];
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      entries.add((
        isHeader: true,
        monthStart: group.monthStart,
        isFirst: i == 0,
        pin: null,
      ));
      for (final pin in group.events) {
        entries.add((
          isHeader: false,
          monthStart: null,
          isFirst: false,
          pin: pin,
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          return _ExploreEventMonthHeader(
            monthStart: entry.monthStart!,
            isFirst: entry.isFirst,
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildEventCard(entry.pin!),
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
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  int _exploreSpotCountForHeader() => _totalSpotsInView ?? _visibleSpots.length;

  String _exploreFiltersDoneLabel(AppLocalizations l10n) {
    if (_isLoadingMapData) {
      return l10n.exploreDoneFilters;
    }
    return l10n.exploreDoneFiltersWithCount(_exploreSpotCountForHeader());
  }

  void _closeFiltersDialog() {
    if (!_showFiltersDialog) return;
    setState(() {
      _showFiltersDialog = false;
    });
  }

  int _exploreEventCountForHeader() => _visibleEvents.length;

  String? _exploreSpotsSegmentSuffix(AppLocalizations l10n) {
    if (_totalSpotsInView != null &&
        _bestShownCount != null &&
        _bestShownCount! < _totalSpotsInView!) {
      return l10n.exploreMapBestShownParenthetical(_bestShownCount!).trim();
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
                  LinkedUpcomingEventPanel(
                    eventsFuture: _linkedSpotListEventsFuture,
                    margin: const EdgeInsets.only(bottom: 12),
                    compact: true,
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
                        _selectedEventPin == null &&
                        !_showListPreview &&
                        !_showFiltersDialog, // Disable location button when expanded, map card is open, list preview is open, or filters dialog is open
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        ((_selectedSpot == null &&
                                _selectedEventPin == null &&
                                !_showListPreview) ||
                            !MobileDetectionService.isMobileDevice),
                    scrollGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        ((_selectedSpot == null &&
                                _selectedEventPin == null &&
                                !_showListPreview) ||
                            !MobileDetectionService.isMobileDevice),
                    rotateGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        ((_selectedSpot == null &&
                                _selectedEventPin == null &&
                                !_showListPreview) ||
                            !MobileDetectionService.isMobileDevice),
                    tiltGesturesEnabled:
                        !_isBottomSheetOpen &&
                        !_showFiltersDialog &&
                        ((_selectedSpot == null &&
                                _selectedEventPin == null &&
                                !_showListPreview) ||
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

                      // Check for locateSpotId / locateEventId query parameters if not already set
                      if (_spotIdToLocate == null || _eventIdToLocate == null) {
                        try {
                          final routerState = GoRouterState.of(context);
                          if (_spotIdToLocate == null) {
                            final locateSpotId =
                                routerState.uri.queryParameters['locateSpotId'];
                            if (locateSpotId != null &&
                                locateSpotId.isNotEmpty) {
                              _spotIdToLocate = locateSpotId;
                            }
                          }
                          if (_eventIdToLocate == null) {
                            final locateEventId = routerState
                                .uri
                                .queryParameters['locateEventId'];
                            if (locateEventId != null &&
                                locateEventId.isNotEmpty) {
                              _eventIdToLocate = locateEventId;
                            }
                          }
                        } catch (e) {
                          // Ignore errors when accessing router state
                        }
                      }

                      // Load spots for the current view after a short delay to ensure map is ready
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (!mounted || _mapController == null) return;
                        _loadMapDataForCurrentView();

                        // If we have a spot ID to locate, locate it after spots are loaded
                        if (_spotIdToLocate != null) {
                          final spotId = _spotIdToLocate!;
                          _spotIdToLocate =
                              null; // Clear before attempting to locate
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) _locateSpotById(spotId);
                          });
                        }

                        if (_eventIdToLocate != null) {
                          final eventId = _eventIdToLocate!;
                          _eventIdToLocate =
                              null; // Clear before attempting to locate
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) _locateEventById(eventId);
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
                      // Dismiss map cards or list preview when map is tapped (but not when markers are tapped)
                      if ((_selectedSpot != null ||
                              _selectedEventPin != null ||
                              _showListPreview) &&
                          !_isBottomSheetOpen) {
                        setState(() {
                          _selectedSpot = null;
                          _selectedEventPin = null;
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
                      _selectedEventPin == null &&
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
                              upcomingEventPin: _upcomingEventPinForSpot(
                                _selectedSpot!,
                              ),
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
                                upcomingEventPin: _upcomingEventPinForSpot(
                                  _selectedSpot!,
                                ),
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

                  // Event Detail Card (when event marker is selected)
                  if (_selectedEventPin != null && !_isBottomSheetOpen)
                    Positioned(
                      left: 16,
                      right: MediaQuery.of(context).size.width >= 600
                          ? null
                          : 16,
                      bottom: 16,
                      child: MediaQuery.of(context).size.width >= 600
                          ? _buildEventOverlayCard(maxWidth: 400)
                          : Center(
                              child: _buildEventOverlayCard(
                                maxWidth: double.infinity,
                              ),
                            ),
                    ),

                  // Spot List Preview Card (when chip is clicked)
                  if (_showListPreview &&
                      _selectedList != null &&
                      !_isBottomSheetOpen &&
                      _selectedSpot == null &&
                      _selectedEventPin == null)
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

                  // Add actions (when long press is detected)
                  if (_longPressedLocation != null &&
                      _selectedSpot == null &&
                      _selectedEventPin == null &&
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
                                          'Add at this location',
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
                                                  path: '/spots/add',
                                                  queryParameters: {
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

                                                // Require profile loaded before navigating to add forms.
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
                                                  context.go(
                                                    addSpotUri.toString(),
                                                  );
                                                }
                                              },
                                              icon: const ReliableIcon(
                                                icon: Icons.add_location,
                                              ),
                                              label: Text('Add spot'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final location =
                                                    _longPressedLocation!;
                                                final addEventUri = Uri(
                                                  path: '/events/add',
                                                  queryParameters: {
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
                                                  _markers = _rebuildMarkers();
                                                });

                                                if (!authService
                                                    .isAuthenticated) {
                                                  context.go(
                                                    '/login?redirectTo=${Uri.encodeComponent(addEventUri.toString())}',
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
                                                  context.go(
                                                    addEventUri.toString(),
                                                  );
                                                }
                                              },
                                              icon: const ReliableIcon(
                                                icon: Icons.event_available,
                                              ),
                                              label: const Text('Add event'),
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

                  // Bottom Sheet with Spots List - hide when map card, list preview, or add spot button is visible
                  if (_selectedSpot == null &&
                      _selectedEventPin == null &&
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
                                    height: _bottomSheetHeight(
                                      MediaQuery.sizeOf(context).height,
                                      _bottomSheetAnimation.value,
                                    ),
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
                                              final l10n = AppLocalizations.of(
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
                                                    _exploreListMode ==
                                                        ExploreBottomSheetHeader
                                                            .modeSpots
                                                    ? _exploreSpotsSegmentSuffix(
                                                        l10n,
                                                      )
                                                    : null,
                                                isSheetOpen: _isBottomSheetOpen,
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
                                                                    ? Icons
                                                                          .search_off
                                                                    : Icons
                                                                          .location_off,
                                                                size: 64,
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withValues(
                                                                          alpha:
                                                                              0.5,
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
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.headlineSmall,
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
                                                                    TextAlign
                                                                        .center,
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(
                                                                      color: Theme.of(context)
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
                      _selectedEventPin == null &&
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
                              _collapsedBottomSheetHeight(
                                MediaQuery.sizeOf(context).height,
                              ) +
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
                      _selectedEventPin == null &&
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
                              _collapsedBottomSheetHeight(
                                MediaQuery.sizeOf(context).height,
                              ) +
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

                  // Location Button - Floating Action Button (only show when bottom sheet is collapsed and no map card open)
                  if (!_isBottomSheetOpen &&
                      _selectedSpot == null &&
                      _selectedEventPin == null &&
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
                              _collapsedBottomSheetHeight(
                                MediaQuery.sizeOf(context).height,
                              ) +
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CallbackShortcuts(
                                    bindings: {
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowDown,
                                      ): _autocompleteSession.highlightNext,
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowUp,
                                      ): _autocompleteSession.highlightPrevious,
                                      const SingleActivator(
                                        LogicalKeyboardKey.escape,
                                      ): _searchFocusNode.unfocus,
                                    },
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(
                                          context,
                                        )!.exploreSearchHint,
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
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            if (!_isSearchingLocation &&
                                                _searchController
                                                    .text
                                                    .isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.clear),
                                                tooltip: AppLocalizations.of(
                                                  context,
                                                )!.exploreClearSearchTooltip,
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _autocompleteSession.clear();
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
                                                      color: _showFiltersDialog
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : null,
                                                    ),
                                                    tooltip: AppLocalizations.of(
                                                      context,
                                                    )!.exploreFiltersTooltip,
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
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
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
                                      onSubmitted: (_) {
                                        final selected = _autocompleteSession
                                            .highlightedOption;
                                        if (selected != null) {
                                          _selectAutocompleteOption(selected);
                                        } else {
                                          _searchAndNavigateToLocation();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                if (!_showFiltersDialog &&
                                    _searchFocusNode.hasFocus &&
                                    _autocompleteSession.showOverlay)
                                  _AutocompleteOverlayContent(
                                    optionsList: _autocompleteSession.options,
                                    currentSelection:
                                        _autocompleteSession.options.isEmpty
                                        ? null
                                        : _autocompleteSession.highlightIndex,
                                    isLoading: _autocompleteSession.isLoading,
                                    onSelected: _selectAutocompleteOption,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
    final l10n = AppLocalizations.of(context)!;
    final canClearFilters = _hasActiveFilters();
    return GestureDetector(
      onTap: _closeFiltersDialog,
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.exploreFiltersDialogTitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              IconButton(
                                onPressed: _closeFiltersDialog,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildFilters(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: l10n.exploreClearFilters,
                                  width: double.infinity,
                                  height: 44,
                                  isOutlined: true,
                                  onPressed: canClearFilters
                                      ? () async {
                                          final searchState =
                                              Provider.of<SearchStateService>(
                                                context,
                                                listen: false,
                                              );
                                          await searchState.clearAllFilters();
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: CustomButton(
                                  text: _exploreFiltersDoneLabel(l10n),
                                  width: double.infinity,
                                  height: 44,
                                  onPressed: _closeFiltersDialog,
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

class _ExploreEventMonthHeader extends StatelessWidget {
  const _ExploreEventMonthHeader({
    required this.monthStart,
    required this.isFirst,
  });

  final DateTime monthStart;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final raw = MaterialLocalizations.of(context).formatMonthYear(monthStart);
    final label = toBeginningOfSentenceCase(raw, localeName);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 20, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
