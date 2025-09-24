import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/sync_source_service.dart';
import '../../widgets/source_details_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  double _userRating = 0;
  double _previousRating = 0; // Track the user's previous rating
  bool _hasRated = false;
  int _currentImageIndex = 0;
  late final ScrollController _scrollController;
  bool _isSatelliteView = false;
  bool _isShareModalOpen = false; // Add this state variable
  
  // Add rating cache variables
  Map<String, dynamic>? _cachedRatingStats;
  bool _isLoadingRatingStats = false;
  
  // Add source name variables
  String? _sourceName;
  bool _isLoadingSourceName = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadRatingStats(); // Load rating stats once on init
    _loadSourceName(); // Load source name if spot has a source
    // Note: User rating will be loaded when auth state is restored via FutureBuilder
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showExternalSpotInfo() async {
    if (widget.spot.spotSource == null) return;
    
    try {
      final syncSourceService = Provider.of<SyncSourceService>(context, listen: false);
      
      // Find the source by ID
      final source = syncSourceService.sources.firstWhere(
        (s) => s.id == widget.spot.spotSource,
        orElse: () => throw Exception('Source not found'),
      );
      
      showDialog(
        context: context,
        builder: (context) => SourceDetailsDialog(source: source),
      );
    } catch (e) {
      // Fallback to simple info dialog if source not found
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.source,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('External Spot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This spot comes from an external source.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'External spots:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                '• May not have all features of native spots',
                '• Could be removed if the source is unavailable',
                '• May have limited editing capabilities',
                '• Data accuracy depends on the original source',
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )),
              if (_sourceName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Source: $_sourceName',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  void _showShareOptions() {
    setState(() {
      _isShareModalOpen = true;
    });
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Spot'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isShareModalOpen = false;
                });
                UrlService.shareSpot(
                  widget.spot.id!,
                  widget.spot.name,
                  countryCode: widget.spot.countryCode,
                  city: widget.spot.city,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Link'),
              onTap: () async {
                Navigator.pop(context);
                setState(() {
                  _isShareModalOpen = false;
                });
                await UrlService.copySpotUrl(
                  widget.spot.id!,
                  countryCode: widget.spot.countryCode,
                  city: widget.spot.city,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Open in Browser'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isShareModalOpen = false;
                });
                UrlService.openSpotInBrowser(
                  widget.spot.id!,
                  countryCode: widget.spot.countryCode,
                  city: widget.spot.city,
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Ensure the state is reset when modal is dismissed
      if (mounted) {
        setState(() {
          _isShareModalOpen = false;
        });
      }
    });
  }





  void _openInMaps() async {
    try {
      await UrlService.openLocationInMaps(
        widget.spot.latitude,
        widget.spot.longitude,
        label: widget.spot.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousImage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextImage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Sliver App Bar with collapsing toolbar
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              floating: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    // Check if we can pop back to a previous page
                    if (Navigator.canPop(context)) {
                      // If there's a previous page, go back to it
                      Navigator.pop(context);
                    } else {
                      // If no previous page (direct link), go to home
                      context.go('/home');
                    }
                  },
                ),
              ),
              actions: [
                // External spot badge
                if (widget.spot.spotSource != null) ...[
                  GestureDetector(
                    onTap: _showExternalSpotInfo,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.source,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Provider.of<SyncSourceService>(context, listen: false)
                                    .getSourceNameSync(widget.spot.spotSource!) ??
                                widget.spot.spotSource!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Share button for all users
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _showShareOptions,
                  ),
                ),
                const SizedBox(width: 8),
                // Login button for unauthenticated users
                if (!Provider.of<AuthService>(context, listen: false).isAuthenticated) ...[
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.login, color: Colors.white),
                      onPressed: () {
                        context.go('/login?redirectTo=${Uri.encodeComponent('/spot/${widget.spot.id}')}');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Edit and Delete buttons - only show after auth state is restored
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    // Wait for auth state to be restored before checking ownership
                    if (authService.isLoading) {
                      // Show subtle loading indicator while auth state is being restored
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      );
                    }
                    
                    // Check if current user owns this spot
                    if (authService.isAuthenticated && 
                        authService.userProfile != null &&
                        widget.spot.createdBy == authService.userProfile!.id) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.8),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: _showDeleteDialog,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      );
                    }
                    
                    // User is authenticated but doesn't own the spot, or auth state not yet restored
                    return const SizedBox.shrink();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageCarousel(),
              ),
            ),
            
            // Content using SliverList
            SliverToBoxAdapter(
              child: Padding(
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
                        // Rating display using cached data
                        _isLoadingRatingStats
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _cachedRatingStats != null && _cachedRatingStats!['ratingCount'] > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _cachedRatingStats!['averageRating'].toStringAsFixed(1),
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${_cachedRatingStats!['ratingCount']})',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
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
                    
                                        // Map view toggle and mobile detection info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
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
                          ],
                        ),
                        

                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Small map widget
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                widget.spot.latitude,
                                widget.spot.longitude,
                              ),
                              zoom: 16,
                            ),
                            mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                            markers: {
                              Marker(
                                markerId: MarkerId(widget.spot.id ?? 'spot'),
                                position: LatLng(
                                  widget.spot.latitude,
                                  widget.spot.longitude,
                                ),
                                // Disable marker interactions
                                onTap: null,
                                consumeTapEvents: true,
                                // Remove info window to prevent popup
                                infoWindow: InfoWindow.noText,
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            liteModeEnabled: kIsWeb,
                            compassEnabled: false,
                            // Completely disable all map interactions for preview purposes
                            zoomGesturesEnabled: false,
                            scrollGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            // Disable any other potential interactions
                            indoorViewEnabled: false,
                            trafficEnabled: false,
                            // Note: onTap is handled by the InkWell overlay below
                          ),
                          // Interactive overlay with subtle hint
                          if (!_isShareModalOpen)
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openInMaps(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          // Enhanced hint positioned at bottom right
                          if (!_isShareModalOpen)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      kIsWeb && MobileDetectionService.isMobileDevice 
                                        ? Icons.phone_android 
                                        : Icons.touch_app,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      kIsWeb && MobileDetectionService.isMobileDevice
                                        ? 'Tap to open in ${MobileDetectionService.preferredMapsApp == 'apple_maps' ? 'Apple Maps' : 'Google Maps'}'
                                        : 'Tap to open map',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Location Information
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Location Details',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${widget.spot.latitude.toStringAsFixed(6)}, ${widget.spot.longitude.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (widget.spot.address != null) ...[
                                  TextSpan(
                                    text: '\n${widget.spot.address}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    
                    const SizedBox(height: 24),
                    

                    
                    // Rating Section
                    Consumer<AuthService>(
                      builder: (context, authService, child) {
                        // Wait for auth state to be restored before showing rating section
                        if (authService.isLoading) {
                          // Show subtle loading indicator while auth state is being restored
                          return SizedBox(
                            height: 80,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading...',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        
                        if (authService.isAuthenticated && authService.userProfile != null) {
                          // Load user rating when auth state is confirmed
                          if (_userRating == 0 && !_hasRated) {
                            // Use FutureBuilder to load user rating asynchronously
                            return FutureBuilder<double?>(
                              future: _loadUserRatingFuture(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Loading your rating...',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                // Rating widget
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                            onTap: () => _submitRatingDirectly(index + 1.0),
                                            child: Icon(
                                              index < _userRating ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 32,
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              },
                            );
                          }
                          
                          // Show rating widget if user rating is already loaded
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      onTap: () => _submitRatingDirectly(index + 1.0),
                                      child: Icon(
                                        index < _userRating ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        } else {
                          // Show login prompt for unauthenticated users
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rate this spot',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Login to rate this spot and help other parkour enthusiasts',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                context.go('/login?redirectTo=${Uri.encodeComponent('/spot/${widget.spot.id}')}');
                                              },
                                              icon: const Icon(Icons.login),
                                              label: const Text('Login to Rate'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        }
                      },
                    ),
                    
                    // Additional Info
                    if (widget.spot.createdBy != null || widget.spot.createdByName != null || widget.spot.createdAt != null) ...[
                      Text(
                        'Additional Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.spot.createdBy != null || widget.spot.createdByName != null) ...[
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Added by'),
                          subtitle: Text(widget.spot.createdByName ?? widget.spot.createdBy ?? ''),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      if (widget.spot.spotSource != null) ...[
                        GestureDetector(
                          onTap: _showExternalSpotInfo,
                          child: ListTile(
                            leading: const Icon(Icons.source),
                            title: const Text('Source'),
                            subtitle: _isLoadingSourceName
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Loading...'),
                                    ],
                                  )
                                : Text(_sourceName ?? 'Unknown Source'),
                            contentPadding: EdgeInsets.zero,
                            trailing: const Icon(Icons.info_outline, size: 16),
                          ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (widget.spot.imageUrls == null || widget.spot.imageUrls!.isEmpty) {
      return Container(
        height: 400,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No images available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
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
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Images: ${widget.spot.imageUrls!.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (kIsWeb) ...[
                      Text(
                        'Mobile: ${MobileDetectionService.isMobileDevice}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      Text(
                        'Platform: ${MobileDetectionService.preferredMapsApp}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          
          // Hybrid image carousel with both swiping and arrow buttons
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: CachedNetworkImage(
              key: ValueKey(_currentImageIndex),
              imageUrl: widget.spot.imageUrls![_currentImageIndex],
              fit: BoxFit.cover,
              width: double.infinity,
              height: 400,
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
            ),
          ),
          
          // Gradient overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),

          // Navigation arrows (left and right)
          if (widget.spot.imageUrls!.length > 1) ...[
            // Left arrow
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _previousImage(),
                  child: Container(
                    width: 48,
                    height: 48,
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
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            
            // Right arrow
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _nextImage(),
                  child: Container(
                    width: 48,
                    height: 48,
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
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Enhanced page indicators and controls
          if (widget.spot.imageUrls!.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Enhanced page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.spot.imageUrls!.length, (index) {
                      final isActive = index == _currentImageIndex;
                      return GestureDetector(
                        onTap: () {
                          // Allow tapping on dots to navigate
                          _goToImage(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isActive ? 6 : 6,
                          height: isActive ? 6 : 6,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ] : null,
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
    );
  }



  void _nextImage() {
    if (_currentImageIndex < widget.spot.imageUrls!.length - 1) {
      setState(() {
        _currentImageIndex++;
      });
    } else {
      // Loop to first image
      setState(() {
        _currentImageIndex = 0;
      });
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      setState(() {
        _currentImageIndex--;
      });
    } else {
      // Loop to last image
      setState(() {
        _currentImageIndex = widget.spot.imageUrls!.length - 1;
      });
    }
  }

  void _goToImage(int index) {
    if (index >= 0 && index < widget.spot.imageUrls!.length) {
      setState(() {
        _currentImageIndex = index;
      });
    }
  }


  Future<double?> _loadUserRatingFuture() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated && authService.userProfile != null) {
        final spotService = Provider.of<SpotService>(context, listen: false);
        final userRating = await spotService.getUserRating(widget.spot.id!, authService.userProfile!.id);
        if (mounted && userRating != null) {
          setState(() {
            _userRating = userRating;
            _previousRating = userRating; // Set the previous rating
            _hasRated = true;
          });
          return userRating;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error loading user rating: $e');
      return null;
    }
  }

  /// Submits a rating directly when a star is clicked (only if different from previous rating)
  Future<void> _submitRatingDirectly(double rating) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to rate spots'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if this is the same rating as before - if so, don't submit
      if (rating == _previousRating && _hasRated) {
        // Just update the UI to show the selected star without submitting
        setState(() {
          _userRating = rating;
        });
        return;
      }
      
      // Store the current rating stats before submitting
      final currentRatingCount = _cachedRatingStats?['ratingCount'] ?? 0;
      final currentAverageRating = _cachedRatingStats?['averageRating'] ?? 0.0;
      
      // Update UI immediately for better UX
      setState(() {
        _userRating = rating;
        _hasRated = true;
        _previousRating = rating;
      });
      
      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.rateSpot(
        widget.spot.id!, 
        rating, 
        authService.userProfile!.id
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rating ${rating.toInt()} star${rating == 1 ? '' : 's'} submitted!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Refresh the spot data to show updated rating
        // Retry a few times to allow Cloud Functions to update the spot aggregates
        await _refreshSpotDataWithRetry(currentRatingCount, currentAverageRating);
      } else if (mounted) {
        // Revert UI changes if submission failed
        setState(() {
          _userRating = _previousRating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit rating. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Revert UI changes if submission failed
        setState(() {
          _userRating = _previousRating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _refreshSpotData() async {
    try {
      // Refresh the rating stats when a user submits a rating
      if (mounted) {
        setState(() {
          _isLoadingRatingStats = true;
        });
        await _loadRatingStats();
      }
    } catch (e) {
      debugPrint('Error refreshing spot data: $e');
    }
  }

  Future<void> _refreshSpotDataWithRetry(int currentRatingCount, double currentAverageRating) async {
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 1000);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      await _refreshSpotData();
      
      // Check if the rating aggregates have changed (indicating the Cloud Function has updated the spot)
      final newRatingCount = _cachedRatingStats?['ratingCount'] ?? 0;
      final newAverageRating = _cachedRatingStats?['averageRating'] ?? 0.0;
      
      // Consider it updated if either count or average has changed
      final countChanged = newRatingCount != currentRatingCount;
      final averageChanged = (newAverageRating - currentAverageRating).abs() > 0.01; // Allow for small floating point differences
      
      if (countChanged || averageChanged) {
        debugPrint('Rating aggregates updated successfully. Count: $currentRatingCount -> $newRatingCount, Average: ${currentAverageRating.toStringAsFixed(2)} -> ${newAverageRating.toStringAsFixed(2)}');
        break; // Success - rating aggregates have been updated
      }
      
      debugPrint('Attempt ${attempt + 1}: Rating aggregates unchanged (Count: $newRatingCount, Average: ${newAverageRating.toStringAsFixed(2)})');
      
      // If not the last attempt, wait before retrying
      if (attempt < maxRetries - 1) {
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> _loadSourceName() async {
    if (widget.spot.spotSource == null) return;
    
    try {
      if (mounted) {
        setState(() {
          _isLoadingSourceName = true;
        });
      }
      
      final syncSourceService = Provider.of<SyncSourceService>(context, listen: false);
      final sourceName = await syncSourceService.getSourceName(widget.spot.spotSource!);
      
      // Use WidgetsBinding to ensure this runs after the current build cycle
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _sourceName = sourceName;
              _isLoadingSourceName = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading source name: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoadingSourceName = false;
            });
          }
        });
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
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final success = await spotService.deleteSpot(widget.spot.id!);
                
                if (success && mounted) {
                  // Show success message first
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Spot deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Navigate to home immediately after successful deletion
                  // Use replace to ensure we don't go back to the deleted spot
                  context.replace('/home');
                } else if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete spot'),
                      backgroundColor: Colors.red,
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
