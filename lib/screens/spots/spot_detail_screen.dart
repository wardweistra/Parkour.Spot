import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import 'package:flutter/foundation.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  double _userRating = 0;
  bool _hasRated = false;
  int _currentImageIndex = 0;
  late final PageController _imagePageController;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _showMapOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Get Directions'),
              onTap: () {
                Navigator.pop(context);
                _openDirections();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('View on Map'),
              onTap: () {
                Navigator.pop(context);
                _openInMaps();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Coordinates'),
              onTap: () {
                Navigator.pop(context);
                _copyCoordinates();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDirections() {
    // TODO: Implement directions (could use url_launcher to open in Maps app)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Directions feature coming soon!')),
    );
  }

  void _openInMaps() {
    // TODO: Implement opening in native maps app
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open in Maps feature coming soon!')),
    );
  }

  void _copyCoordinates() {
    // TODO: Implement copying coordinates to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coordinates: ${widget.spot.location.latitude.toStringAsFixed(6)}, ${widget.spot.location.longitude.toStringAsFixed(6)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (widget.spot.createdBy == Provider.of<AuthService>(context, listen: false).userProfile?.id) ...[
            CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  // TODO: Navigate to edit screen
                },
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: _showDeleteDialog,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            if (widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty)
              Container(
                height: 300,
                width: double.infinity,
                child: Stack(
                  children: [
                    // Debug info
                    if (kDebugMode)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Images: ${widget.spot.imageUrls!.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    
                    // Swipeable image carousel
                    PageView.builder(
                      controller: _imagePageController,
                      onPageChanged: (index) {
                        print('Page changed to index: $index'); // Debug log
                        setState(() => _currentImageIndex = index);
                      },
                      itemCount: widget.spot.imageUrls!.length,
                      physics: const PageScrollPhysics(), // Enable page swiping
                      itemBuilder: (context, index) {
                        final url = widget.spot.imageUrls![index];
                        return CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            debugPrint('Image error: $error');
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image failed to load',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),

                    // Page indicators
                    if (widget.spot.imageUrls!.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            // Current image counter
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_currentImageIndex + 1} of ${widget.spot.imageUrls!.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Swipe hint text
                            Text(
                              'Swipe to view more images',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Page indicator dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(widget.spot.imageUrls!.length, (index) {
                                final isActive = index == _currentImageIndex;
                                return GestureDetector(
                                  onTap: () {
                                    // Allow tapping on dots to navigate
                                    _imagePageController.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? 12 : 8,
                                    height: isActive ? 12 : 8,
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white : Colors.white54,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.spot.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.spot.rating != null) ...[
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.spot.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.spot.ratingCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.spot.ratingCount})',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.spot.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tags
                  if (widget.spot.tags != null && widget.spot.tags!.isNotEmpty) ...[
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.spot.tags!.map((tag) {
                        return Chip(
                          label: Text(tag),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Location
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Location coordinates
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.spot.location.latitude.toStringAsFixed(4)}°, ${widget.spot.location.longitude.toStringAsFixed(4)}°',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Small map widget
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          widget.spot.location.latitude,
                          widget.spot.location.longitude,
                        ),
                        zoom: 16,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(widget.spot.id ?? 'spot'),
                          position: LatLng(
                            widget.spot.location.latitude,
                            widget.spot.location.longitude,
                          ),
                          infoWindow: InfoWindow(
                            title: widget.spot.name,
                            snippet: widget.spot.description.length > 50
                                ? '${widget.spot.description.substring(0, 50)}...'
                                : widget.spot.description,
                          ),
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      onTap: (_) {
                        // Open full map view or navigation
                        _showMapOptions(context);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Rating Section
                  if (Provider.of<AuthService>(context, listen: false).userProfile != null) ...[
                    Text(
                      'Rate this spot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _userRating = index + 1.0;
                                _hasRated = true;
                              });
                            },
                            child: Icon(
                              index < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                          );
                        }),
                        const SizedBox(width: 16),
                        if (_hasRated)
                          CustomButton(
                            onPressed: _submitRating,
                            text: 'Submit Rating',
                            isLoading: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Additional Info
                  if (widget.spot.createdBy != null || widget.spot.createdAt != null) ...[
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.spot.createdBy != null) ...[
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Added by'),
                        subtitle: Text(widget.spot.createdBy!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (widget.spot.createdAt != null) ...[
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Created on'),
                        subtitle: Text(_formatDate(widget.spot.createdAt!)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (widget.spot.updatedAt != null && 
                        widget.spot.updatedAt != widget.spot.createdAt) ...[
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('Last updated'),
                        subtitle: Text(_formatDate(widget.spot.updatedAt!)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.rateSpot(widget.spot.id!, _userRating);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasRated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spot'),
        content: const Text('Are you sure you want to delete this spot? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final spotService = Provider.of<SpotService>(context, listen: false);
                final success = await spotService.deleteSpot(widget.spot.id!);
                
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Spot deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting spot: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
