import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../models/spot.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isSpotSheetOpen = false;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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

  Set<Marker> _buildMarkers(List<Spot> spots) {
    return spots.map((spot) {
      return Marker(
        markerId: MarkerId(spot.id ?? spot.name),
        position: LatLng(spot.location.latitude, spot.location.longitude),
        onTap: () {
          // Show enhanced bottom sheet with spot details
          _showSpotBottomSheet(spot);
        },
      );
    }).toSet();
  }

  void _showSpotBottomSheet(Spot spot) {
    setState(() {
      _isSpotSheetOpen = true;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SpotBottomSheet(spot: spot),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isSpotSheetOpen = false;
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Satellite view toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Standard',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: !_isSatelliteView 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Switch(
                value: _isSatelliteView,
                onChanged: (value) {
                  setState(() {
                    _isSatelliteView = value;
                  });
                },
              ),
              Text(
                'Satellite',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isSatelliteView 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement map filters
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map filters coming soon!')),
              );
            },
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Spots',
          ),
        ],
      ),
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
                    'Error loading map',
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
              GoogleMap(
                initialCameraPosition: initialCameraPosition,
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                markers: _buildMarkers(spotService.spots),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                zoomGesturesEnabled: !_isSpotSheetOpen,
                scrollGesturesEnabled: !_isSpotSheetOpen,
                rotateGesturesEnabled: !_isSpotSheetOpen,
                tiltGesturesEnabled: !_isSpotSheetOpen,
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
                },
              ),
              

              
              // Floating action button for centering on user location
              if (_isGettingLocation)
                const Positioned(
                  top: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Finding location...'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SpotBottomSheet extends StatefulWidget {
  final Spot spot;

  const _SpotBottomSheet({required this.spot});

  @override
  State<_SpotBottomSheet> createState() => _SpotBottomSheetState();
}

class _SpotBottomSheetState extends State<_SpotBottomSheet> {
  late PageController _pageController;
  int _currentPage = 0;
  
  // Add rating cache variables
  Map<String, dynamic>? _cachedRatingStats;
  bool _isLoadingRatingStats = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadRatingStats(); // Load rating stats once on init
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
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
          
          // View details button - moved to top for always visibility
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/spot/${widget.spot.id}');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Full Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section with full gallery functionality
                  if (widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          children: [
                            // Image Gallery with PageView
                            PageView.builder(
                              controller: _pageController,
                              itemCount: widget.spot.imageUrls!.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: widget.spot.imageUrls![index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Page Indicator Dots (only show if multiple images)
                            if (widget.spot.imageUrls!.length > 1)
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    widget.spot.imageUrls!.length,
                                    (index) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: index == _currentPage 
                                            ? Colors.white 
                                            : Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Navigation arrows (left and right)
                            if (widget.spot.imageUrls!.length > 1) ...[
                              // Left arrow
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () => _previousImage(),
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
                                    onTap: () => _nextImage(),
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
                    )
                  else
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_on,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Title and Rating Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.spot.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rating display using cached data
                      _isLoadingRatingStats
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _cachedRatingStats != null && _cachedRatingStats!['ratingCount'] > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _cachedRatingStats!['averageRating'].toStringAsFixed(1),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    widget.spot.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tags
                  if (widget.spot.tags != null && widget.spot.tags!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.label,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.spot.tags!.join(', '),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Created by and date
                  if (widget.spot.createdBy != null || widget.spot.createdByName != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Added by ${widget.spot.createdByName ?? widget.spot.createdBy}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        if (widget.spot.createdAt != null) ...[
                          Text(
                            _formatDate(widget.spot.createdAt!),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _nextImage() {
    if (_currentPage < widget.spot.imageUrls!.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to first image
      setState(() {
        _currentPage = 0;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to last image
      setState(() {
        _currentPage = widget.spot.imageUrls!.length - 1;
      });
      _pageController.animateToPage(
        widget.spot.imageUrls!.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadRatingStats() async {
    try {
      setState(() {
        _isLoadingRatingStats = true;
      });
      final spotService = Provider.of<SpotService>(context, listen: false);
      final ratingStats = await spotService.getSpotRatingStats(widget.spot.id!);
      if (mounted) {
        setState(() {
          _cachedRatingStats = ratingStats;
          _isLoadingRatingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rating stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingRatingStats = false;
        });
      }
    }
  }
}
