import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/spot_service.dart';
import '../../models/spot.dart';
import '../../widgets/spot_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isBottomSheetOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Spot> _visibleSpots = [];
  Set<Marker> _markers = {};
  late AnimationController _bottomSheetAnimationController;
  late Animation<double> _bottomSheetAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
    
    // Initialize bottom sheet animation
    _bottomSheetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bottomSheetAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _bottomSheetAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bottomSheetAnimationController.dispose();
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
          setState(() {
            _currentPosition = position;
          });

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
    });
  }

  void _onMapCameraMove() {
    // Update visible spots when map moves
    _updateVisibleSpots();
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

          // Determine initial camera position
          final CameraPosition initialCameraPosition = CameraPosition(
            target: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : spotService.spots.isNotEmpty
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
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                zoomGesturesEnabled: !_isBottomSheetOpen,
                scrollGesturesEnabled: !_isBottomSheetOpen,
                rotateGesturesEnabled: !_isBottomSheetOpen,
                tiltGesturesEnabled: !_isBottomSheetOpen,
                liteModeEnabled: kIsWeb,
                compassEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  
                  // Move to user location if available
                  if (_currentPosition != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      ),
                    );
                  }
                  
                  // Initial update of visible spots
                  _updateVisibleSpots();
                },
                onCameraMove: (CameraPosition position) {
                  _onMapCameraMove();
                },
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
                              icon: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
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

              // Bottom Sheet with Spots List
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _bottomSheetAnimation,
                  builder: (context, child) {
                    return Container(
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
                          // Handle bar
                          GestureDetector(
                            onTap: _toggleBottomSheet,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Header with spot count
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_visibleSpots.length} spots found',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _toggleBottomSheet,
                                  icon: Icon(
                                    _isBottomSheetOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Spots List
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
                                : ListView.builder(
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
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
