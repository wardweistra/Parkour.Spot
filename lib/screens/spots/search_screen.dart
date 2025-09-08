import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/spot_service.dart';
import '../../models/spot.dart';
import '../../widgets/spot_card.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Spot> _visibleSpots = [];
  Set<Marker> _markers = {};
  Spot? _selectedSpot;
  late AnimationController _bottomSheetAnimationController;
  late Animation<double> _bottomSheetAnimation;
  late PageController _imagePageController;
  int _currentImageIndex = 0;
  double _dragStartY = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Removed automatic location fetching - now user-controlled
    _searchController.addListener(_onSearchChanged);
    
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bottomSheetAnimationController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _updateVisibleSpots();
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
          // Move camera to user location if map is ready
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(position.latitude, position.longitude),
              ),
            );
          }
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

  void _updateVisibleSpots() {
    final spotService = Provider.of<SpotService>(context, listen: false);
    List<Spot> filteredSpots = spotService.spots;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredSpots = spotService.searchSpots(_searchQuery);
    }

    // Filter spots within visible map bounds
    if (_mapController != null) {
      _mapController!.getVisibleRegion().then((bounds) {
        final visibleSpots = filteredSpots.where((spot) {
          final lat = spot.location.latitude;
          final lng = spot.location.longitude;
          return lat >= bounds.southwest.latitude &&
                 lat <= bounds.northeast.latitude &&
                 lng >= bounds.southwest.longitude &&
                 lng <= bounds.northeast.longitude;
        }).toList();

        setState(() {
          _visibleSpots = visibleSpots;
          _markers = _buildMarkers(visibleSpots);
        });
      });
    } else {
      // If map not ready, show all filtered spots
      setState(() {
        _visibleSpots = filteredSpots;
        _markers = _buildMarkers(filteredSpots);
      });
    }
  }

  Set<Marker> _buildMarkers(List<Spot> spots) {
    return spots.map((spot) {
      return Marker(
        markerId: MarkerId(spot.id ?? spot.name),
        position: LatLng(spot.location.latitude, spot.location.longitude),
        onTap: () {
          // Select the spot and show detail card
          setState(() {
            _selectedSpot = spot;
            _currentImageIndex = 0; // Reset to first image
          });
          
          // Center map on selected spot
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(spot.location.latitude, spot.location.longitude),
            ),
          );
        },
      );
    }).toSet();
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

  void _onMapCameraMove() {
    // Update visible spots when map moves
    _updateVisibleSpots();
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
                  LatLng(spot.location.latitude, spot.location.longitude),
                ),
              );
              // Navigate to spot detail
              context.go('/spot/${spot.id}');
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
                    LatLng(spot.location.latitude, spot.location.longitude),
                  ),
                );
                // Navigate to spot detail
                context.go('/spot/${spot.id}');
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
      body: Consumer<SpotService>(
        builder: (context, spotService, child) {
          if (spotService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (spotService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading spots',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spotService.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => spotService.fetchSpots(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Determine initial camera position - use first spot or default location
          final CameraPosition initialCameraPosition = CameraPosition(
            target: spotService.spots.isNotEmpty
                ? LatLng(spotService.spots.first.location.latitude, spotService.spots.first.location.longitude)
                : const LatLng(37.7749, -122.4194), // Default to San Francisco
            zoom: 14,
          );

          return Stack(
            children: [
              // Map View
              GoogleMap(
                initialCameraPosition: initialCameraPosition,
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: !_isBottomSheetOpen, // Disable location button when expanded
                zoomControlsEnabled: false,
                zoomGesturesEnabled: !_isBottomSheetOpen,
                scrollGesturesEnabled: !_isBottomSheetOpen,
                rotateGesturesEnabled: !_isBottomSheetOpen,
                tiltGesturesEnabled: !_isBottomSheetOpen,
                liteModeEnabled: kIsWeb,
                compassEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  
                  // Initial update of visible spots
                  _updateVisibleSpots();
                },
                onCameraMove: (CameraPosition position) {
                  _onMapCameraMove();
                },
              ),

              // Map clickable overlay when bottom sheet is expanded
              if (_isBottomSheetOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleBottomSheet, // Collapse sheet when map is tapped
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // Map clickable overlay when spot detail card is shown
              if (_selectedSpot != null && !_isBottomSheetOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      // Clear selected spot when map is tapped
                      setState(() {
                        _selectedSpot = null;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // Top Search Bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search spots...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : IconButton(
                              icon: ReliableIcon(
                                icon: _isSatelliteView ? Icons.map : Icons.terrain,
                              ),
                              tooltip: _isSatelliteView ? 'Switch to Map' : 'Switch to Satellite',
                              onPressed: () {
                                setState(() {
                                  _isSatelliteView = !_isSatelliteView;
                                });
                              },
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
                  ),
                ),
              ),

              // Location Loading Indicator
              if (_isGettingLocation)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  right: 16,
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

              // Spot Detail Card (when marker is selected)
              if (_selectedSpot != null && !_isBottomSheetOpen)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Center(
                    child: GestureDetector(
                    onTap: () {
                      // Navigate to spot detail
                      context.go('/spot/${_selectedSpot!.id}');
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Spot image gallery
                          if (_selectedSpot!.imageUrls != null && _selectedSpot!.imageUrls!.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  children: [
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
                                        });
                                      },
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Close',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedSpot!.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                      context.go('/spot/${_selectedSpot!.id}');
                                    },
                                    child: const Text('View Details'),
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

              // Bottom Sheet with Spots List - hide when spot detail card is visible
              if (_selectedSpot == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _bottomSheetAnimation,
                    builder: (context, child) {
                    return GestureDetector(
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
                                   Text(
                                     '${_visibleSpots.length} ${_visibleSpots.length == 1 ? 'spot' : 'spots'} found',
                                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                       fontWeight: FontWeight.bold,
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
                    );
                  },
                ),
                ),

              // Location Button - Floating Action Button
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).size.height * 0.09 + 16, // Position above bottom sheet
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
            ],
          );
        },
      ),
    );
  }
}
