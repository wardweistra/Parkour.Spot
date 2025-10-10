import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../services/spot_service.dart';
import '../../services/sync_source_service.dart';
import '../../services/search_state_service.dart';
import '../../services/url_service.dart';
import '../../services/geocoding_service.dart';
import '../../models/spot.dart';
import '../../widgets/spot_card.dart';
import '../../widgets/source_details_dialog.dart';

// Helper widget to ensure icons render properly on mobile web
class ReliableIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const ReliableIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
  });

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
    
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isBottomSheetOpen = false; // Start collapsed by default
  Position? _currentPosition;
  BitmapDescriptor? _userLocationIcon;
  BitmapDescriptor? _spotDefaultIcon; // Web fallback
  BitmapDescriptor? _spotSelectedIcon; // Web fallback
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _placesSessionToken;
  // Autocomplete is fetched live in optionsBuilder; no debounce field needed
  List<Spot> _visibleSpots = [];
  List<Spot> _loadedSpots = []; // Spots loaded for the current map view
  Set<Marker> _markers = {};
  Spot? _selectedSpot;
  bool _isLoadingSpotsForView = false; // Loading state for spots within current view
  int? _totalSpotsInView; // Total unfiltered spots in current bounds
  int? _bestShownCount; // Number of ranked spots returned (up to 100)
  late AnimationController _bottomSheetAnimationController;
  late Animation<double> _bottomSheetAnimation;
  late PageController _imagePageController;
  int _currentImageIndex = 0;
  double _dragStartY = 0.0;
  bool _isDragging = false;
  // Filters
  bool _includeSpotsWithoutPictures = true; // Default: include spots without pictures
  bool _includeParkourNative = true; // Spots created directly on parkour.spot (spotSource == null)
  bool _includeExternalSources = true; // Spots from external sources (spotSource != null)
  Set<String> _selectedExternalSourceIds = <String>{}; // Will be populated with all source IDs by default
  bool _showFiltersDialog = false; // Controls filters dialog visibility
  SpotService? _spotServiceRef; // To attach a listener for spot updates
  SyncSourceService? _syncSourceServiceRef; // To attach a listener for sync source updates
  
  void _onSpotsChanged() {
    if (mounted) {
      _updateVisibleSpots();
    }
  }
  
  void _onSyncSourcesChanged() {
    if (mounted && _syncSourceServiceRef != null) {
      // Select saved external sources if available, otherwise select all by default when they load
      if (_syncSourceServiceRef!.sources.isNotEmpty && _selectedExternalSourceIds.isEmpty) {
        final searchState = Provider.of<SearchStateService>(context, listen: false);
        final savedIds = searchState.selectedExternalSourceIds;
        if (savedIds.isNotEmpty) {
          final availableIds = _syncSourceServiceRef!.sources.map((s) => s.id).toSet();
          _selectedExternalSourceIds.clear();
          _selectedExternalSourceIds.addAll(savedIds.intersection(availableIds));
        } else {
          _selectedExternalSourceIds.clear();
          _selectedExternalSourceIds.addAll(_syncSourceServiceRef!.sources.map((s) => s.id));
        }
        // Persist selected sources
        searchState.setSelectedExternalSourceIds(_selectedExternalSourceIds);
        _updateVisibleSpots();
      }
    }
  }

  bool _hasActiveFilters() {
    // Check if any filters are different from defaults
    return !_includeSpotsWithoutPictures || // Default is true, so false means active
           !_includeParkourNative || // Default is true, so false means active
           !_includeExternalSources || // Default is true, so false means active
           (_includeExternalSources && _selectedExternalSourceIds.isNotEmpty && 
            _selectedExternalSourceIds.length != (_syncSourceServiceRef?.sources.length ?? 0)); // Not all sources selected
  }

  @override
  void initState() {
    super.initState();
    // Removed automatic location fetching - now user-controlled
    _searchController.addListener(_onSearchChanged);
    _loadUserLocationIcon();
    _loadSpotIcons();
    
    // Initialize bottom sheet animation
    _bottomSheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(
      begin: 0.09, // Very compact when collapsed - minimal footprint
      end: 0.75,   // Less expanded - still good for browsing but leaves more map visible
    ).animate(CurvedAnimation(
      parent: _bottomSheetAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize image page controller
    _imagePageController = PageController();

    // Preload external sync sources for filters
    // Safe to call with listen: false in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load persisted search state and apply to UI
      final searchState = Provider.of<SearchStateService>(context, listen: false);
      setState(() {
        _isSatelliteView = searchState.isSatellite;
        _includeSpotsWithoutPictures = searchState.includeSpotsWithoutPictures;
        _includeParkourNative = searchState.includeParkourNative;
        _includeExternalSources = searchState.includeExternalSources;
        if (searchState.selectedExternalSourceIds.isNotEmpty) {
          _selectedExternalSourceIds = {...searchState.selectedExternalSourceIds};
        }
      });

      // Listen to SpotService changes to refresh visible spots when data updates
      _spotServiceRef = Provider.of<SpotService>(context, listen: false);
      _spotServiceRef!.addListener(_onSpotsChanged);

      // Listen to SyncSourceService changes to update selected sources
      _syncSourceServiceRef = Provider.of<SyncSourceService>(context, listen: false);
      _syncSourceServiceRef!.addListener(_onSyncSourcesChanged);

      if (_syncSourceServiceRef!.sources.isEmpty && !_syncSourceServiceRef!.isLoading) {
        _syncSourceServiceRef!.fetchSyncSources(includeInactive: false);
      } else if (_syncSourceServiceRef!.sources.isNotEmpty) {
        // If sources are already loaded, prefer saved selection; otherwise select all
        final savedIds = searchState.selectedExternalSourceIds;
        if (savedIds.isNotEmpty) {
          final availableIds = _syncSourceServiceRef!.sources.map((s) => s.id).toSet();
          _selectedExternalSourceIds
            ..clear()
            ..addAll(savedIds.intersection(availableIds));
        } else {
          _selectedExternalSourceIds
            ..clear()
            ..addAll(_syncSourceServiceRef!.sources.map((s) => s.id));
        }
      }
    });
  }

  @override
  void dispose() {
    _cameraMoveDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bottomSheetAnimationController.dispose();
    _imagePageController.dispose();
    // Remove listeners
    _spotServiceRef?.removeListener(_onSpotsChanged);
    _syncSourceServiceRef?.removeListener(_onSyncSourcesChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    // Suggestions are fetched directly by Autocomplete.optionsBuilder
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
    if (types.contains('locality') || types.contains('administrative_area_level_3')) {
      return 12.0;
    }
    
    // Neighborhood level - close zoom
    if (types.contains('sublocality') || types.contains('neighborhood')) {
      return 13.0;
    }
    
    // Specific places (restaurants, businesses, etc.) - very close zoom
    if (types.contains('establishment') || types.contains('point_of_interest')) {
      return 15.0;
    }
    
    // Default zoom level for other types
    return 13.5;
  }

  Future<void> _selectPlaceSuggestion(Map<String, dynamic> suggestion) async {
    try {
      
      final geocoding = Provider.of<GeocodingService>(context, listen: false);
      final placeId = suggestion['placeId'] as String?;
      if (placeId == null) {
        return;
      }
      final details = await geocoding.placeDetails(
        placeId: placeId,
        sessionToken: _placesSessionToken,
      );
      // Reset session token after a selection per Google guidelines
      _placesSessionToken = null;
      if (details == null) return;
      final double? lat = (details['latitude'] as num?)?.toDouble();
      final double? lng = (details['longitude'] as num?)?.toDouble();
      final String? formatted = details['formattedAddress'] as String? ?? details['formatted_address'] as String?;
      
      if (lat != null && lng != null && _mapController != null) {
        final zoomLevel = _getZoomLevelForPlace(details);
        await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoomLevel,
        )));
      }
      // Update search field
      setState(() {
        _searchController.text = formatted ?? (suggestion['description'] as String? ?? '');
        _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
      });
      // Trigger a refresh of visible spots for new area
      _updateVisibleSpots();
    } catch (e) {
      // Log errors for debugging
      debugPrint('Error selecting place: $e');
      // No-op: suggestions list is now built live by optionsBuilder
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          // Move camera to user location if map is ready
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(position.latitude, position.longitude),
                  zoom: 13.5,
                ),
              ),
            );
          }
          // Refresh markers to include current location
          _updateVisibleSpots();
        }
      }
    } catch (e) {
      // Handle error silently for map view
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // Load spots for the current map view
  Future<void> _loadSpotsForCurrentView() async {
    if (_mapController == null) {
      return;
    }
    
    setState(() {
      _isLoadingSpotsForView = true;
    });

    try {
      final bounds = await _mapController!.getVisibleRegion();
      
      final spotService = Provider.of<SpotService>(context, listen: false);
      
      // Load ranked top spots within the current map bounds (and total count)
      final ranked = await spotService.getTopRankedSpotsInBounds(
        bounds.southwest.latitude,
        bounds.northeast.latitude,
        bounds.southwest.longitude,
        bounds.northeast.longitude,
        limit: 100,
      );

      _loadedSpots = (ranked['spots'] as List<Spot>?) ?? <Spot>[];
      _totalSpotsInView = ranked['totalCount'] as int?;
      _bestShownCount = ranked['shownCount'] as int?;
      
      // Apply filters to the loaded spots
      _updateVisibleSpots();
    } catch (e) {
      debugPrint('Error loading spots for current view: $e');
    } finally {
      setState(() {
        _isLoadingSpotsForView = false;
      });
    }
  }

  void _updateVisibleSpots() {
    List<Spot> filteredSpots = List.from(_loadedSpots);
    
    // Note: Search query is now only used for location autocomplete, not spot name filtering

    // Apply picture filter (default: exclude spots without pictures)
    if (!_includeSpotsWithoutPictures) {
      filteredSpots = filteredSpots.where((spot) => spot.imageUrls != null && spot.imageUrls!.isNotEmpty).toList();
    }

    // Apply source filters
    filteredSpots = filteredSpots.where((spot) {
      final bool isExternal = (spot.spotSource != null && spot.spotSource!.isNotEmpty);

      if (isExternal) {
        if (!_includeExternalSources) {
          return false; // exclude all external
        }
        // If external sources are enabled, check if this specific source is selected
        if (_selectedExternalSourceIds.isEmpty) {
          return false; // exclude all external when none selected
        }
        return _selectedExternalSourceIds.contains(spot.spotSource);
      } else {
        // Native Parkour.Spot (no spotSource)
        return _includeParkourNative;
      }
    }).toList();

    // Update visible spots and markers
    setState(() {
      _visibleSpots = filteredSpots;
      _markers = _buildMarkers(filteredSpots);
    });
  }

  

  Widget _buildFilters() {
    return Consumer<SyncSourceService>(
      builder: (context, syncService, child) {
        final sources = syncService.sources..sort((a, b) => a.name.compareTo(b.name));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // Row 1: Include spots without pictures
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include spots without pictures'),
                    value: _includeSpotsWithoutPictures,
                    onChanged: (val) {
                      setState(() {
                        _includeSpotsWithoutPictures = val;
                      });
                      Provider.of<SearchStateService>(context, listen: false)
                          .setIncludeSpotsWithoutPictures(val);
                      _updateVisibleSpots();
                    },
                  ),
                  // Row 2: Include Parkour.Spot native
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Parkour.Spot native spots'),
                    subtitle: const Text('Spots added directly on parkour.spot'),
                    value: _includeParkourNative,
                    onChanged: (val) {
                      setState(() {
                        _includeParkourNative = val;
                      });
                      Provider.of<SearchStateService>(context, listen: false)
                          .setIncludeParkourNative(val);
                      _updateVisibleSpots();
                    },
                  ),
                  // Row 3: Include external sources
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include external sources'),
                    subtitle: const Text('Spots from external spot sources'),
                    value: _includeExternalSources,
                    onChanged: (val) {
                      setState(() {
                        _includeExternalSources = val;
                      });
                      Provider.of<SearchStateService>(context, listen: false)
                          .setIncludeExternalSources(val);
                      _updateVisibleSpots();
                    },
                  ),
                  if (_includeExternalSources) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'External sources',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _selectedExternalSourceIds.length == (_syncSourceServiceRef?.sources.length ?? 0)
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedExternalSourceIds.clear();
                                        _selectedExternalSourceIds.addAll(_syncSourceServiceRef!.sources.map((s) => s.id));
                                      });
                                      Provider.of<SearchStateService>(context, listen: false)
                                          .setSelectedExternalSourceIds(_selectedExternalSourceIds);
                                      // Call _updateVisibleSpots after setState completes
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _updateVisibleSpots();
                                      });
                                    },
                              child: const Text('Show All'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _selectedExternalSourceIds.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedExternalSourceIds.clear();
                                      });
                                      Provider.of<SearchStateService>(context, listen: false)
                                          .setSelectedExternalSourceIds(_selectedExternalSourceIds);
                                      // Call _updateVisibleSpots after setState completes
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _updateVisibleSpots();
                                      });
                                    },
                              child: const Text('Show None'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (syncService.isLoading && sources.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (syncService.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Failed to load sources',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sources.map((source) {
                          final bool selected = _selectedExternalSourceIds.contains(source.id);
                          return _buildSourceChipWithInfo(context, source, selected);
                        }).toList(),
                      ),
                  ],
                ],
          );
      },
    );
  }

  Set<Marker> _buildMarkers(List<Spot> spots) {
    final markers = spots.map((spot) {
      final bool isSelected = _selectedSpot?.id != null
          ? _selectedSpot!.id == spot.id
          : _selectedSpot?.name == spot.name;
      // On web, use generated icons because hue-based markers are not supported.
      final BitmapDescriptor icon = kIsWeb
          ? (isSelected
              ? (_spotSelectedIcon ?? BitmapDescriptor.defaultMarker)
              : (_spotDefaultIcon ?? BitmapDescriptor.defaultMarker))
          : (isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose)
              : BitmapDescriptor.defaultMarker);
      return Marker(
        markerId: MarkerId(spot.id ?? spot.name),
        position: LatLng(spot.latitude, spot.longitude),
        icon: icon,
        onTap: () {
          // Select the spot and show detail card
          setState(() {
            _selectedSpot = spot;
            _currentImageIndex = 0; // Reset to first image
            // Rebuild markers to reflect selection color
            _markers = _buildMarkers(_visibleSpots);
          });
        },
      );
    }).toSet();

    // Add current user location marker if available
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _userLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndexInt: 9999,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is your current location'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    }

    return markers;
  }

  Future<void> _loadUserLocationIcon() async {
    try {
      final icon = await _createUserLocationIcon(size: 24, fillColor: Colors.blue);
      if (mounted) {
        setState(() {
          _userLocationIcon = icon;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
    }
  }

  Future<BitmapDescriptor> _createUserLocationIcon({double size = 24, Color fillColor = Colors.blue}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;
    final Offset center = Offset(radius, radius);

    final Paint shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    final Paint ringPaint = Paint()..color = Colors.white;
    final Paint fillPaint = Paint()..color = fillColor;

    // Calculate proportional border thickness (was 4px for 96px icon, now scales)
    final double borderThickness = size * 4 / 96; // Scale from 4px at 96px size
    final double innerRadius = radius - borderThickness;

    // Shadow circle
    canvas.drawCircle(center, radius, shadowPaint);
    // Outer white ring
    canvas.drawCircle(center, innerRadius, ringPaint);
    // Inner fill
    canvas.drawCircle(center, innerRadius - borderThickness * 2, fillPaint);

    final ui.Image image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes);
  }

  Future<void> _loadSpotIcons() async {
    try {
      // Simple circular icons to ensure consistent coloring on web
      final BitmapDescriptor defaultIcon = await _createUserLocationIcon(size: 22, fillColor: Colors.red);
      // Make selected more distinct and smaller
      final BitmapDescriptor selectedIcon = await _createUserLocationIcon(size: 22, fillColor: Color(0xFFFF8A80));
      if (mounted) {
        setState(() {
          _spotDefaultIcon = defaultIcon;
          _spotSelectedIcon = selectedIcon;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
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

  Timer? _cameraMoveDebounce;
  
  void _onMapCameraMove(CameraPosition position) {
    // Persist camera position
    final searchState = Provider.of<SearchStateService>(context, listen: false);
    searchState.saveMapCamera(
      position.target.latitude,
      position.target.longitude,
      position.zoom,
    );
    
    // Debounce loading spots to avoid too many requests while user is panning
    _cameraMoveDebounce?.cancel();
    _cameraMoveDebounce = Timer(const Duration(milliseconds: 1000), () {
      _loadSpotsForCurrentView();
    });
  }

  void _nextImage() {
    if (_selectedSpot?.imageUrls != null && _currentImageIndex < _selectedSpot!.imageUrls!.length - 1) {
      setState(() {
        _currentImageIndex++;
      });
      _imagePageController.animateToPage(
        _currentImageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_selectedSpot?.imageUrls != null && _selectedSpot!.imageUrls!.isNotEmpty) {
      // Loop to first image
      setState(() {
        _currentImageIndex = 0;
      });
      _imagePageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_selectedSpot?.imageUrls != null && _currentImageIndex > 0) {
      setState(() {
        _currentImageIndex--;
      });
      _imagePageController.animateToPage(
        _currentImageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_selectedSpot?.imageUrls != null && _selectedSpot!.imageUrls!.isNotEmpty) {
      // Loop to last image
      setState(() {
        _currentImageIndex = _selectedSpot!.imageUrls!.length - 1;
      });
      _imagePageController.animateToPage(
        _selectedSpot!.imageUrls!.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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
          return SpotCard(
            spot: spot,
            onTap: () {
              // Center map on selected spot
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(spot.latitude, spot.longitude),
                ),
              );
              // Navigate to spot detail using proper URL format
              final navigationUrl = UrlService.generateNavigationUrl(
                spot.id!,
                countryCode: spot.countryCode,
                city: spot.city,
              );
              context.go(navigationUrl);
            },
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SpotCard(
              spot: spot,
              onTap: () {
                // Center map on selected spot
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(spot.latitude, spot.longitude),
                  ),
                );
                // Navigate to spot detail using proper URL format
                final navigationUrl = UrlService.generateNavigationUrl(
                  spot.id!,
                  countryCode: spot.countryCode,
                  city: spot.city,
                );
                context.go(navigationUrl);
              },
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Determine initial camera position - use persisted state, user location, or default
          Consumer<SearchStateService>(
            builder: (context, searchState, child) {
              LatLng initialTarget = const LatLng(37.7749, -122.4194); // Default to San Francisco
              double initialZoom = 14;
              
              // Use persisted camera position if available
              if (searchState.centerLat != null && searchState.centerLng != null && searchState.zoom != null) {
                initialTarget = LatLng(searchState.centerLat!, searchState.centerLng!);
                initialZoom = searchState.zoom!;
              }
              // Otherwise try to use current user location
              else if (_currentPosition != null) {
                initialTarget = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
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
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: !_isBottomSheetOpen && _selectedSpot == null && !_showFiltersDialog, // Disable location button when expanded, spot detail is open, or filters dialog is open
                zoomControlsEnabled: false,
                zoomGesturesEnabled: !_isBottomSheetOpen && _selectedSpot == null && !_showFiltersDialog,
                scrollGesturesEnabled: !_isBottomSheetOpen && _selectedSpot == null && !_showFiltersDialog,
                rotateGesturesEnabled: !_isBottomSheetOpen && _selectedSpot == null && !_showFiltersDialog,
                tiltGesturesEnabled: !_isBottomSheetOpen && _selectedSpot == null && !_showFiltersDialog,
                liteModeEnabled: kIsWeb,
                compassEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  
                  // Load spots for the current view after a short delay to ensure map is ready
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _loadSpotsForCurrentView();
                  });
                  
                  // Restore persisted camera after map is ready (in case state loaded late)
                  final state = Provider.of<SearchStateService>(context, listen: false);
                  if (state.centerLat != null && state.centerLng != null && state.zoom != null) {
                    controller.moveCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(state.centerLat!, state.centerLng!),
                          zoom: state.zoom!,
                        ),
                      ),
                    );
                  } else {
                    // If no persisted camera, try to center on user's current location
                    _getCurrentLocation();
                  }
                },
                onCameraMove: (CameraPosition position) {
                  _onMapCameraMove(position);
                },
                onTap: (LatLng position) {
                  // Dismiss spot detail card when map is tapped (but not when markers are tapped)
                  if (_selectedSpot != null && !_isBottomSheetOpen) {
                    setState(() {
                      _selectedSpot = null;
                      // Rebuild markers to clear selection color
                      _markers = _buildMarkers(_visibleSpots);
                    });
                  }
                },
              ),

              // Map clickable overlay when bottom sheet is expanded
              if (_isBottomSheetOpen)
                Positioned.fill(
                  child: PointerInterceptor(
                    child: GestureDetector(
                      onTap: _toggleBottomSheet, // Collapse sheet when map is tapped
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),

              // Top Search Bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          final query = textEditingValue.text.trim();
                          if (query.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }

                          // Keep _searchQuery in sync (without triggering external fetches)
                          if (_searchQuery != query) {
                            setState(() {
                              _searchQuery = query;
                            });
                          }

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

                          
                          try {
                            final geocoding = Provider.of<GeocodingService>(context, listen: false);
                            final results = await geocoding.placesAutocomplete(
                              input: query,
                              sessionToken: _placesSessionToken,
                              biasLat: center?.latitude,
                              biasLng: center?.longitude,
                              radiusMeters: 50000,
                            );
                            
                            return results;
                          } catch (e) {
                            
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                        },
                        onSelected: (Map<String, dynamic> suggestion) async {
                          await _selectPlaceSuggestion(suggestion);
                        },
                        displayStringForOption: (Map<String, dynamic> option) {
                          return option['description'] as String? ?? '';
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Search location…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Loading indicator removed; optionsBuilder fetches live
                                  if (textEditingController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: 'Clear',
                                      onPressed: () {
                                        textEditingController.clear();
                                        // optionsBuilder will return empty for empty query
                                        setState(() {});
                                      },
                                    ),
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: ReliableIcon(
                                          icon: Icons.filter_list,
                                          color: _showFiltersDialog ? Theme.of(context).colorScheme.primary : null,
                                        ),
                                        tooltip: 'Filters',
                                        onPressed: () {
                                          setState(() {
                                            _showFiltersDialog = !_showFiltersDialog;
                                          });
                                        },
                                      ),
                                      if (_hasActiveFilters())
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          );
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Map<String, dynamic>> onSelected, Iterable<Map<String, dynamic>> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: PointerInterceptor(
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      final description = option['description'] as String? ?? '';
                                      final secondary = option['secondary'] as String?;
                                      
                                      return ListTile(
                                        leading: Icon(
                                          Icons.location_on_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        dense: true,
                                        title: Text(
                                          description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: secondary != null ? Text(
                                          secondary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ) : null,
                                        onTap: () {
                                          onSelected(option);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text('Finding location...'),
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
                  right: 16,
                  bottom: 16,
                  child: Center(
                    child: PointerInterceptor(
                      child: GestureDetector(
                      onTap: () {
                        // Navigate to spot detail using proper URL format
                        final navigationUrl = UrlService.generateNavigationUrl(
                          _selectedSpot!.id!,
                          countryCode: _selectedSpot!.countryCode,
                          city: _selectedSpot!.city,
                        );
                        context.go(navigationUrl);
                      },
                      child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width >= 600 ? 400 : double.infinity,
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
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Spot image gallery or location marker
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    children: [
                                      if (_selectedSpot!.imageUrls != null && _selectedSpot!.imageUrls!.isNotEmpty) ...[
                                        // Image Gallery with PageView
                                        PageView.builder(
                                          controller: _imagePageController,
                                          itemCount: _selectedSpot!.imageUrls!.length,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentImageIndex = index;
                                            });
                                          },
                                          itemBuilder: (context, index) {
                                            return Image.network(
                                              _selectedSpot!.imageUrls![index],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        
                                        // Page Indicator Dots (only show if multiple images)
                                        if (_selectedSpot!.imageUrls!.length > 1)
                                          Positioned(
                                            bottom: 8,
                                            left: 0,
                                            right: 0,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: List.generate(
                                                _selectedSpot!.imageUrls!.length,
                                                (index) => Container(
                                                  width: 6,
                                                  height: 6,
                                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: index == _currentImageIndex 
                                                        ? Colors.white 
                                                        : Colors.white.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        // Navigation arrows (left and right)
                                        if (_selectedSpot!.imageUrls!.length > 1) ...[
                                          // Left arrow
                                          Positioned(
                                            left: 8,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: GestureDetector(
                                                onTap: _previousImage,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.6),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white.withValues(alpha: 0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.chevron_left,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          // Right arrow
                                          Positioned(
                                            right: 8,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: GestureDetector(
                                                onTap: _nextImage,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.6),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white.withValues(alpha: 0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ] else ...[
                                        // Location marker when no images
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.location_on,
                                              size: 48,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                      
                                      // External source indicator - positioned on the image/marker area
                                      if (_selectedSpot!.spotSource != null)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.4),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              Provider.of<SyncSourceService>(context, listen: false)
                                                      .getSourceNameSync(_selectedSpot!.spotSource!) ??
                                                  _selectedSpot!.spotSource!,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          
                          // Spot details
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedSpot!.name,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedSpot = null;
                                          // Rebuild markers to clear selection color
                                          _markers = _buildMarkers(_visibleSpots);
                                        });
                                      },
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Close',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedSpot!.description.trim().isEmpty 
                                      ? 'No description provided'
                                      : _selectedSpot!.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontStyle: _selectedSpot!.description.trim().isEmpty 
                                        ? FontStyle.italic 
                                        : FontStyle.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedSpot!.tags != null && _selectedSpot!.tags!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedSpot!.tags!.join(', '),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final navigationUrl = UrlService.generateNavigationUrl(
                                        _selectedSpot!.id!,
                                        countryCode: _selectedSpot!.countryCode,
                                        city: _selectedSpot!.city,
                                      );
                                      context.go(navigationUrl);
                                    },
                                    child: const Text('View Details'),
                                  ),
                                ),
                              ],
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

              // Bottom Sheet with Spots List - hide when spot detail card is visible
              if (_selectedSpot == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _bottomSheetAnimation,
                    builder: (context, child) {
                    return PointerInterceptor(
                      child: GestureDetector(
                        onTap: _isBottomSheetOpen ? null : _toggleBottomSheet, // Only clickable when collapsed
                        onPanStart: _handleDragStart, // Always enable drag gestures
                        onPanUpdate: _handleDragUpdate,
                        onPanEnd: _handleDragEnd,
                        child: Container(
                          height: MediaQuery.of(context).size.height * _bottomSheetAnimation.value,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header with spot count
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    RichText(
                                       text: TextSpan(
                                         children: [
                                           TextSpan(
                                             text: _totalSpotsInView != null && _bestShownCount != null
                                                 ? '$_totalSpotsInView spots'
                                                 : '${_visibleSpots.length} ${_visibleSpots.length == 1 ? 'spot' : 'spots'} found',
                                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                               fontWeight: FontWeight.bold,
                                               color: Theme.of(context).colorScheme.onSurface,
                                             ),
                                           ),
                                           if (_totalSpotsInView != null && _bestShownCount != null && _bestShownCount! < _totalSpotsInView!)
                                             TextSpan(
                                               text: ' ($_bestShownCount best shown)',
                                               style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                 fontWeight: FontWeight.normal,
                                                 color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                               ),
                                             ),
                                         ],
                                       ),
                                     ),
                                    IconButton(
                                      onPressed: _toggleBottomSheet,
                                      tooltip: _isBottomSheetOpen ? 'Collapse' : 'Expand',
                                      icon: ReliableIcon(
                                        icon: _isBottomSheetOpen ? Icons.expand_more : Icons.expand_less,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Spots List - only show when expanded
                              if (_isBottomSheetOpen)
                                Expanded(
                                  child: _visibleSpots.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.location_off,
                                                size: 64,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.isNotEmpty ? 'No spots found' : 'No spots in this area',
                                                style: Theme.of(context).textTheme.headlineSmall,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _searchQuery.isNotEmpty
                                                    ? 'Try adjusting your search terms'
                                                    : 'Move the map to explore different areas',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _buildSpotsList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ),

              // Refresh Spots Button - Floating Action Button
              if (!_isBottomSheetOpen && _selectedSpot == null)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).size.height * 0.09 + 144, // Position above map/satellite button
                  child: PointerInterceptor(
                    child: FloatingActionButton(
                      onPressed: _isLoadingSpotsForView ? null : () {
                        _loadSpotsForCurrentView();
                      },
                      mini: true,
                      tooltip: 'Refresh spots in current view',
                      child: _isLoadingSpotsForView
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const ReliableIcon(
                              icon: Icons.refresh,
                            ),
                    ),
                  ),
                ),

              // Map Type Toggle Button - Floating Action Button
              if (!_isBottomSheetOpen && _selectedSpot == null)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).size.height * 0.09 + 80, // Position above location button
                  child: PointerInterceptor(
                    child: FloatingActionButton(
                      onPressed: () {
                        setState(() {
                          _isSatelliteView = !_isSatelliteView;
                        });
                        final searchState = Provider.of<SearchStateService>(context, listen: false);
                        searchState.setSatellite(_isSatelliteView);
                      },
                      mini: true,
                      tooltip: _isSatelliteView ? 'Switch to Map' : 'Switch to Satellite',
                      child: ReliableIcon(
                        icon: _isSatelliteView ? Icons.map : Icons.terrain,
                      ),
                    ),
                  ),
                ),

              // Location Button - Floating Action Button (only show when bottom sheet is collapsed and no spot selected)
              if (!_isBottomSheetOpen && _selectedSpot == null)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).size.height * 0.09 + 16, // Position above bottom sheet
                  child: PointerInterceptor(
                    child: FloatingActionButton(
                      onPressed: _getCurrentLocation,
                      mini: true,
                      tooltip: 'Center on my location',
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
                ),
            ],
          );
        },
      ),
          // Filters Dialog
          if (_showFiltersDialog)
            _buildFiltersDialog(),
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
        color: Colors.black.withValues(alpha: 0.5), // Semi-transparent background
        child: Center(
          child: PointerInterceptor(
            child: GestureDetector(
              onTap: () {
                // Prevent dialog from closing when tapping inside
              },
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
                    'Filters',
                    style: Theme.of(context).textTheme.headlineSmall,
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
            
            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showFiltersDialog = false;
                    });
                    _updateVisibleSpots();
                  },
                  child: const Text('Apply Filters'),
                ),
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
    );
  }

  Widget _buildSourceChipWithInfo(BuildContext context, SyncSource source, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          label: Text('${source.name}    '),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedExternalSourceIds.add(source.id);
              } else {
                _selectedExternalSourceIds.remove(source.id);
              }
            });
            Provider.of<SearchStateService>(context, listen: false)
                .setSelectedExternalSourceIds(_selectedExternalSourceIds);
            // Call _updateVisibleSpots after setState completes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateVisibleSpots();
            });
          },
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => SourceDetailsDialog(source: source),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

