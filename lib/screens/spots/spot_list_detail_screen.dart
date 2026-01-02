import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart' as web;
import '../../models/spot_list.dart';
import '../../models/spot.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/feature_access_service.dart';
import '../../services/search_state_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../widgets/spot_card.dart';
import '../../services/snackbar_service.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/map_bounds_utils.dart';
import 'package:flutter/services.dart';

class SpotListDetailScreen extends StatefulWidget {
  final String listId;
  final String? referrer;

  const SpotListDetailScreen({super.key, required this.listId, this.referrer});

  @override
  State<SpotListDetailScreen> createState() => _SpotListDetailScreenState();
}

class _SpotListDetailScreenState extends State<SpotListDetailScreen> {
  SpotList? _list;
  List<Spot> _spots = [];
  bool _isLoading = true;
  String? _error;
  bool _isSatelliteView = false;
  GoogleMapController? _mapController;
  BitmapDescriptor? _spotHighlightedIcon; // Black icon for spots in list
  BitmapDescriptor? _spotSelectedHighlightedIcon; // Grey icon for selected spot
  Spot? _selectedSpot; // Currently selected/highlighted spot
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadList();
    _loadSpotIcons();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSpotIcons() async {
    try {
      // Black icon for spots in list (matching highlighted style from Explore)
      final BitmapDescriptor highlightedIcon = await MarkerIconUtils.createMarkerIcon(
        size: 22,
        fillColor: Colors.black,
      );
      // Grey icon for selected spot (matching selectedHighlighted style from Explore)
      final BitmapDescriptor selectedHighlightedIcon = await MarkerIconUtils.createMarkerIcon(
        size: 22,
        fillColor: Colors.grey.shade400,
      );
      if (mounted) {
        setState(() {
          _spotHighlightedIcon = highlightedIcon;
          _spotSelectedHighlightedIcon = selectedHighlightedIcon;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final spotListService = Provider.of<SpotListService>(context, listen: false);
    final list = await spotListService.getSpotListById(widget.listId);

    if (list == null) {
      setState(() {
        _isLoading = false;
        _error = 'List not found';
      });
      return;
    }

    setState(() {
      _list = list;
    });

    // Load spots
    if (list.spotIds.isNotEmpty) {
      await _loadSpots(list.spotIds);
    } else {
      setState(() {
        _isLoading = false;
        _spots = [];
      });
    }
  }

  Future<void> _loadSpots(List<String> spotIds) async {
    final spotService = Provider.of<SpotService>(context, listen: false);
    final List<Spot> loadedSpots = [];

    for (final spotId in spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) {
        loadedSpots.add(spot);
      }
    }

    setState(() {
      _spots = loadedSpots;
      _isLoading = false;
    });
    
    // Fit bounds after spots are loaded
    if (loadedSpots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    }
  }

  Future<void> _removeSpot(String spotId) async {
    final spotListService = Provider.of<SpotListService>(context, listen: false);
    final success = await spotListService.removeSpotFromList(widget.listId, spotId);

    if (success) {
      SnackbarService.showSuccess('Spot removed from list');
      // Reload the list
      await _loadList();
    } else {
      SnackbarService.showError(spotListService.error ?? 'Failed to remove spot');
    }
  }

  Future<void> _deleteList() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${_list?.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && _list?.id != null) {
      final spotListService = Provider.of<SpotListService>(context, listen: false);
      final success = await spotListService.deleteSpotList(_list!.id!);

      if (success) {
        SnackbarService.showSuccess('List deleted');
        if (context.mounted) {
          context.pop();
        }
      } else {
        SnackbarService.showError(spotListService.error ?? 'Failed to delete list');
      }
    }
  }

  Widget _buildSpotsList() {
    if (_spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No spots in this list',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add spots from spot detail pages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600; // Use grid layout on wider screens
    final canManage = _canManageList();

    if (useGrid) {
      // Calculate optimal grid dimensions based on screen size
      final maxCrossAxisExtent = 480.0;
      final mainAxisExtent = 440.0; // Height to accommodate bottom content

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          mainAxisExtent: mainAxisExtent,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _spots.length,
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return SpotCard(
            spot: spot,
            onTapWithImageIndex: (imageIndex) {
              // Navigate to spot detail with image index
              final baseUrl = spot.id != null ? '/spot/${spot.id}' : null;
              if (baseUrl != null) {
                final navigationUrl = imageIndex > 0 ? '$baseUrl?imageIndex=$imageIndex' : baseUrl;
                // Use push to maintain navigation stack
                context.push(navigationUrl);
                // Update browser URL after a delay to ensure GoRouter has finished
                if (kIsWeb) {
                  Future.delayed(const Duration(milliseconds: 200), () {
                    // Push new state to update URL while maintaining back button
                    web.window.history.pushState(null, '', navigationUrl);
                  });
                }
              }
            },
            onLocate: () => _locateSpot(spot),
            onRemove: canManage && spot.id != null
                ? () => _removeSpot(spot.id!)
                : null,
          );
        },
      );
    } else {
      // Use list layout on narrower screens
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _spots.length,
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SpotCard(
              spot: spot,
              onTapWithImageIndex: (imageIndex) {
                // Navigate to spot detail with image index
                final baseUrl = spot.id != null ? '/spot/${spot.id}' : null;
                if (baseUrl != null) {
                  final navigationUrl = imageIndex > 0 ? '$baseUrl?imageIndex=$imageIndex' : baseUrl;
                  context.push(navigationUrl);
                }
              },
              onLocate: () => _locateSpot(spot),
              onRemove: canManage && spot.id != null
                  ? () => _removeSpot(spot.id!)
                  : null,
            ),
          );
        },
      );
    }
  }

  Future<void> _editList() async {
    if (_list == null) return;

    final nameController = TextEditingController(text: _list!.name);
    final descriptionController = TextEditingController(text: _list!.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'List Name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('List name cannot be empty')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && _list?.id != null) {
      final spotListService = Provider.of<SpotListService>(context, listen: false);
      final success = await spotListService.updateSpotList(
        _list!.id!,
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      if (success) {
        SnackbarService.showSuccess('List updated');
        await _loadList();
      } else {
        SnackbarService.showError(spotListService.error ?? 'Failed to update list');
      }
    }
  }

  bool _canManageList() {
    if (_list == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    
    final userId = authService.currentUser?.uid;
    if (userId == null || _list!.createdBy != userId) return false;
    
    final featureAccessService = FeatureAccessService(authService);
    return featureAccessService.hasFeatureAccess('spotLists');
  }

  // Copy list URL to clipboard (same style as spot detail page)
  void _copyListToClipboard() async {
    if (_list?.id == null || _list?.name == null) return;
    
    try {
      const baseUrl = 'https://parkour.spot';
      final url = '$baseUrl/list/${_list!.id}';
      final text = '${_list!.name.trim()} 👉 $url';

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy list: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Calculate bounds to fit all spots with 5% margin
  LatLngBounds? _calculateBounds() {
    return calculateBoundsForSpots(_spots);
  }

  // Build markers for all spots
  Set<Marker> _buildMarkers() {
    return _spots.map((spot) {
      final bool isSelected = _selectedSpot?.id != null
          ? _selectedSpot!.id == spot.id
          : _selectedSpot?.name == spot.name;
      
      // Use grey icon for selected spot, black for others (matching Explore page style)
      final BitmapDescriptor icon = kIsWeb
          ? (isSelected
              ? (_spotSelectedHighlightedIcon ?? BitmapDescriptor.defaultMarker)
              : (_spotHighlightedIcon ?? BitmapDescriptor.defaultMarker))
          : (isSelected
              ? (_spotSelectedHighlightedIcon ?? BitmapDescriptor.defaultMarker)
              : (_spotHighlightedIcon ?? BitmapDescriptor.defaultMarker));
      
      return Marker(
        markerId: MarkerId(spot.id ?? spot.name),
        position: LatLng(spot.latitude, spot.longitude),
        icon: icon,
        onTap: null,
        consumeTapEvents: true,
        infoWindow: InfoWindow.noText,
      );
    }).toSet();
  }

  // Locate a spot: scroll to map and highlight it
  Future<void> _locateSpot(Spot spot) async {
    // Scroll to top to show the map
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Select the spot and refresh markers to show grey highlight
    if (mounted) {
      setState(() {
        _selectedSpot = spot;
      });
    }
  }

  // Navigate to explore page with list highlighted
  void _showListOnMap() {
    if (_list?.id != null) {
      context.go('/explore?listId=${_list!.id}');
    }
  }

  // Get initial camera position based on bounds
  CameraPosition? _getInitialCameraPosition() {
    final bounds = _calculateBounds();
    if (bounds == null) return null;

    // Calculate center
    final centerLat = (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final centerLng = (bounds.southwest.longitude + bounds.northeast.longitude) / 2;

    // Calculate approximate zoom level based on bounds
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Approximate zoom calculation (this is a rough estimate)
    double zoom = 10.0;
    if (maxDiff > 0.1) {
      zoom = 8.0;
    } else if (maxDiff > 0.05) {
      zoom = 9.0;
    } else if (maxDiff > 0.01) {
      zoom = 11.0;
    } else if (maxDiff > 0.005) {
      zoom = 12.0;
    } else {
      zoom = 13.0;
    }

    return CameraPosition(
      target: LatLng(centerLat, centerLng),
      zoom: zoom,
    );
  }

  // Fit map to show all markers with bounds
  Future<void> _fitBounds() async {
    if (_mapController == null) return;
    
    final bounds = _calculateBounds();
    if (bounds == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0), // 50px padding
    );
  }

  Widget _buildMap() {
    if (_spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final initialCameraPosition = _getInitialCameraPosition();
    if (initialCameraPosition == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
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
            initialCameraPosition: initialCameraPosition,
            mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
            markers: _buildMarkers(),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Fit bounds after map is created
              _fitBounds();
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            liteModeEnabled: kIsWeb,
            compassEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
          ),
          Positioned.fill(
            child: PointerInterceptor(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showListOnMap,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Map Type Toggle Button
          Positioned(
            bottom: 24,
            right: 10,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isSatelliteView = !_isSatelliteView;
                  });
                  final searchState = Provider.of<SearchStateService>(context, listen: false);
                  searchState.setSatellite(_isSatelliteView);
                },
                heroTag: 'mapTypeToggleFab',
                mini: true,
                tooltip: _isSatelliteView ? 'Switch to Map' : 'Switch to Satellite',
                child: Icon(
                  _isSatelliteView ? Icons.map : Icons.terrain,
                ),
              ),
            ),
          ),
          // Hint text
          Positioned(
            top: 8,
            right: 8,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MobileDetectionService.isMobileDevice
                          ? Icons.phone_android
                          : Icons.touch_app,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Highlight list on map',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final canManage = _canManageList();
    final theme = Theme.of(context);
    final appBarHeight = kToolbarHeight;
    
    return Container(
      height: appBarHeight + MediaQuery.of(context).padding.top,
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // If we have a referrer, go back to that location
                    if (widget.referrer == 'profile') {
                      context.go('/explore?tab=profile');
                    } else if (Navigator.canPop(context)) {
                      // If there's a previous page, go back to it
                      Navigator.pop(context);
                    } else {
                      // If no previous page (direct link), go to explore
                      context.go('/explore');
                    }
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _list?.name ?? 'Spot List',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                // Share button for all users
                if (_list != null && _list!.id != null)
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share List',
                    onPressed: _copyListToClipboard,
                  ),
                if (_list != null && canManage) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit List',
                    onPressed: _editList,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete List',
                    onPressed: _deleteList,
                  ),
                ],
                // Spacer to balance the back button
                if (_list == null || (_list!.id == null && !canManage))
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
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
                                  _error!,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    // If we have a referrer, go back to that location
                                    if (widget.referrer == 'profile') {
                                      context.go('/explore?tab=profile');
                                    } else if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    } else {
                                      context.go('/explore');
                                    }
                                  },
                                  child: const Text('Go Back'),
                                ),
                              ],
                            ),
                          )
                        : _list == null
                            ? const Center(child: Text('List not found'))
                            : SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  children: [
                                    // Map showing all spots
                                    if (_spots.isNotEmpty) _buildMap(),
                                    // List info header
                                    if (_list!.description != null && _list!.description!.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          _list!.description!,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    // Spots list
                                    _buildSpotsList(),
                                  ],
                                ),
                              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

