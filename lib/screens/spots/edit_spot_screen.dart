import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/search_state_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/attributes_section.dart';
import '../../screens/spots/location_picker_screen.dart';
import '../../utils/map_recentering_mixin.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/image_preparation.dart';

class EditSpotScreen extends StatefulWidget {
  final Spot spot;

  const EditSpotScreen({
    super.key,
    required this.spot,
  });

  @override
  State<EditSpotScreen> createState() => _EditSpotScreenState();
}

class _EditSpotScreenState extends State<EditSpotScreen> with MapRecenteringMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Location state
  LatLng? _currentLocation;
  String? _currentAddress;
  String? _currentCity;
  String? _currentCountryCode;
  bool _isGettingLocation = false;
  bool _isGeocoding = false;
  bool _isSatelliteView = false;
  bool _isLocationPermissionDenied = false;
  SearchStateService? _searchStateServiceRef;

  // Image state
  final List<Uint8List?> _selectedImageBytes = [];
  final List<String> _existingImageUrls = [];
  final List<String> _imagesToDelete = [];

  // YouTube links state
  final List<TextEditingController> _youtubeControllers = [];

  // Duplicate state
  String? _duplicateOf;

  // Attributes state
  String? _selectedAccess;
  final Set<String> _selectedFeatures = {};
  final Map<String, String> _selectedFacilities = {};
  final Set<String> _selectedGoodFor = {};

  // Loading state
  bool _isLoading = false;
  
  // Warning banner state (for admin editing spot-source spots)
  bool _warningDismissed = false;

  // Moderator action fields state
  String? _selectedReportId;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeForm();
    
    // Check permission status on initialization to show correct icon
    _checkLocationPermission();
    
    // Initialize satellite view from SearchStateService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(context, listen: false);
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() {
        _isSatelliteView = _searchStateServiceRef!.isSatellite;
      });
    });
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;
    
    setState(() {
      _isSatelliteView = searchState.isSatellite;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Center map on location after the map controller is created
    if (_currentLocation != null) {
      centerMapAfterBuild(_currentLocation!);
    }
  }

  void _initializeForm() {
    // Initialize form fields with existing spot data
    _nameController.text = widget.spot.name;
    _descriptionController.text = widget.spot.description;

    // Initialize location
    _currentLocation = LatLng(widget.spot.latitude, widget.spot.longitude);
    _currentAddress = widget.spot.address;
    _currentCity = widget.spot.city;
    _currentCountryCode = widget.spot.countryCode;

    // Initialize existing images
    _existingImageUrls.addAll(widget.spot.imageUrls ?? []);

    // Initialize YouTube links
    final youtubeIds = widget.spot.youtubeVideoIds ?? [];
    for (final id in youtubeIds) {
      final controller = TextEditingController(text: id);
      _youtubeControllers.add(controller);
    }

    // Initialize duplicateOf
    _duplicateOf = widget.spot.duplicateOf;

    // Initialize attributes
    _selectedAccess = widget.spot.spotAccess;
    _selectedFeatures.addAll(widget.spot.spotFeatures ?? []);
    _selectedFacilities.addAll(widget.spot.spotFacilities ?? {});
    _selectedGoodFor.addAll(widget.spot.goodFor ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    for (final controller in _youtubeControllers) {
      controller.dispose();
    }
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    // Only show as denied if it's permanently denied, not if it's just not asked yet
    final isDenied = permission == LocationPermission.deniedForever;
    
    if (mounted) {
      setState(() {
        _isLocationPermissionDenied = isDenied;
      });
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
    
    final isPermissionGranted = LocationPermissionUtils.isPermissionGranted(permission);
    
    if (mounted) {
      setState(() {
        _isLocationPermissionDenied = !isPermissionGranted;
      });
    }

    if (!isPermissionGranted) {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLocationPermissionDenied = false;
        });
        // Center the map on the new current location with a small delay to ensure controller is ready
        centerMapOnLocationWithDelay(LatLng(position.latitude, position.longitude));
        await _geocodeLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
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

  Future<void> _geocodeLocation(double latitude, double longitude) async {
    try {
      setState(() {
        _isGeocoding = true;
      });

      final geocodingService = Provider.of<GeocodingService>(context, listen: false);
      final result = await geocodingService.geocodeCoordinatesDetails(latitude, longitude);

      if (mounted) {
        setState(() {
          _currentAddress = result['address'];
          _currentCity = result['city'];
          _currentCountryCode = result['countryCode'];
        });
      }
    } catch (e) {
      debugPrint('Error geocoding location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _currentLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentLocation = result;
      });
      // Center the map on the new picked location with a small delay to ensure controller is ready
      centerMapOnLocationWithDelay(result);
      await _geocodeLocation(result.latitude, result.longitude);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        for (final image in images) {
          try {
            final bytes = await image.readAsBytes();
            final prepared = await prepareImageForUpload(bytes);
            if (mounted) {
              setState(() => _selectedImageBytes.add(prepared.bytes));
            }
          } on ImagePreparationException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ImagePreparationException
                  ? e.message
                  : 'Failed to pick images. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        if (mounted) {
          setState(() => _selectedImageBytes.add(prepared.bytes));
        }
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to take photo. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSelectedImageAt(int index) {
    setState(() {
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes[index] = null;
      }
    });
  }

  void _removeExistingImageAt(int index) {
    setState(() {
      final imageUrl = _existingImageUrls[index];
      _existingImageUrls.removeAt(index);
      
      // Only add to _imagesToDelete if this URL no longer exists in the remaining list
      // This prevents removing all duplicates when we only want to remove one instance
      if (!_existingImageUrls.contains(imageUrl)) {
        _imagesToDelete.add(imageUrl);
      }
    });
  }

  void _reorderExistingImage(int oldIndex, int newIndex) {
    setState(() {
      final imageUrl = _existingImageUrls.removeAt(oldIndex);
      _existingImageUrls.insert(newIndex, imageUrl);
    });
  }

  void _reorderSelectedImage(int oldIndex, int newIndex) {
    setState(() {
      final imageBytes = _selectedImageBytes.removeAt(oldIndex);
      _selectedImageBytes.insert(newIndex, imageBytes);
    });
  }


  void _toggleSatelliteView(bool value) {
    setState(() {
      _isSatelliteView = value;
    });
    final searchState = Provider.of<SearchStateService>(context, listen: false);
    searchState.setSatellite(value);
  }

  void _toggleFeature(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedFeatures.add(key);
      } else {
        _selectedFeatures.remove(key);
      }
    });
  }

  void _toggleGoodFor(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedGoodFor.add(key);
      } else {
        _selectedGoodFor.remove(key);
      }
    });
  }

  void _onFacilityChanged(String key, String value) {
    setState(() {
      _selectedFacilities[key] = value;
    });
  }

  void _onAccessChanged(String? value) {
    setState(() {
      _selectedAccess = value;
    });
  }

  // Extract YouTube ID from URL or return as-is if already an ID
  String? _extractYoutubeId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    // If it's already a likely ID, return as-is (11 chars typical)
    if (RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(trimmed) && !trimmed.contains('/')) {
      return trimmed;
    }
    try {
      final uri = Uri.parse(trimmed);
      // youtu.be/<id>
      if (uri.host.contains('youtu.be')) {
        final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
        if (seg != null && seg.isNotEmpty) return seg;
      }
      // youtube.com/watch?v=<id>
      final vParam = uri.queryParameters['v'];
      if (vParam != null && vParam.isNotEmpty) return vParam;
      // youtube.com/embed/<id>
      final embedIndex = uri.pathSegments.indexOf('embed');
      if (embedIndex != -1 && embedIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[embedIndex + 1];
      }
      // youtube.com/shorts/<id>
      final shortsIndex = uri.pathSegments.indexOf('shorts');
      if (shortsIndex != -1 && shortsIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[shortsIndex + 1];
      }
    } catch (_) {}
    return trimmed; // Fallback to raw value
  }

  void _addYoutubeLink() {
    setState(() {
      _youtubeControllers.add(TextEditingController());
    });
  }

  void _removeYoutubeLink(int index) {
    setState(() {
      _youtubeControllers[index].dispose();
      _youtubeControllers.removeAt(index);
    });
  }

  Future<void> _saveSpot() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    // Only require images for non-moderators (moderators can save spots without images)
    final authService = Provider.of<AuthService>(context, listen: false);
    final isModeratorOrAdmin = authService.isModerator || authService.isAdmin;
    if (!isModeratorOrAdmin && _existingImageUrls.isEmpty && _selectedImageBytes.every((bytes) => bytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);

      // Extract YouTube IDs from controllers
      final youtubeIds = _youtubeControllers
          .map((controller) => _extractYoutubeId(controller.text))
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      // Create updated spot data with reordered existing image URLs
      // The updateSpot method will remove deleted images and add new ones,
      // but it starts with spot.imageUrls, so we pass the reordered list here
      final updatedSpot = widget.spot.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        imageUrls: _existingImageUrls.isNotEmpty ? _existingImageUrls : null,
        youtubeVideoIds: youtubeIds.isEmpty ? <String>[] : youtubeIds,
        duplicateOf: _duplicateOf,
        spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.toList(),
        spotFacilities: _selectedFacilities,
        goodFor: _selectedGoodFor.toList(),
        updatedAt: DateTime.now(),
        hidden: widget.spot.hidden, // Preserve existing hidden field
      );

      // Filter out null values for images
      final validNewImageBytes = _selectedImageBytes.where((bytes) => bytes != null).cast<Uint8List>().toList();

      // Get user info for audit logging (moderator edits)
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final userName = authService.userProfile?.displayName ?? authService.currentUser?.displayName ?? authService.currentUser?.email;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      final success = await spotService.updateSpot(
        updatedSpot,
        newImageFiles: null,
        newImageBytesList: validNewImageBytes.isNotEmpty ? validNewImageBytes : null,
        imagesToDelete: _imagesToDelete.isNotEmpty ? _imagesToDelete : null,
        userId: userId,
        userName: userName,
        reportId: _selectedReportId,
        notes: notes,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Spot updated successfully!')),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update spot')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating spot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating spot: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Check if user is moderator or admin
        if (!authService.isModerator && !authService.isAdmin) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
            ),
            body: const Center(
              child: Text('Only moderators can edit spots'),
            ),
          );
        }

        // Check if spot is from a source and user is moderator (not admin)
        if (widget.spot.spotSource != null && authService.isModerator && !authService.isAdmin) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Cannot Edit Spot'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This spot is from an external source',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Spots imported from external sources cannot be edited directly. '
                    'To make changes, first create a native spot from this one, then edit the native spot.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (widget.spot.spotSourceName != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.source, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Source',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  Text(
                                    widget.spot.spotSourceName!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Spot'),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Warning banner for admins editing spot-source spots
                  if (widget.spot.spotSource != null && authService.isAdmin && !_warningDismissed)
                    Card(
                      color: Colors.orange.shade50,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Warning: Editing Spot from External Source',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This spot is imported from an external source (${widget.spot.spotSourceName ?? 'unknown source'}). '
                                    'Any changes you make may be overwritten when the source syncs again. '
                                    'Consider creating a native spot instead if you want to make permanent changes.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: Colors.orange.shade700,
                              onPressed: () {
                                setState(() {
                                  _warningDismissed = true;
                                });
                              },
                              tooltip: 'Dismiss warning',
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Location Section
                  SpotLocationSection(
                    currentLocation: _currentLocation,
                    address: _currentAddress,
                    countryCode: _currentCountryCode,
                    isGettingLocation: _isGettingLocation,
                    isGeocoding: _isGeocoding,
                    isSatelliteView: _isSatelliteView,
                    isLocationPermissionDenied: _isLocationPermissionDenied,
                    onRefreshLocation: _getCurrentLocation,
                    onPickOnMap: _pickOnMap,
                    onToggleSatellite: _toggleSatelliteView,
                    onMapCreated: onMapCreated,
                  ),
                  const SizedBox(height: 16),

                  // Image Section
                  SpotImageSection(
                    selectedImageBytes: _selectedImageBytes,
                    existingImageUrls: _existingImageUrls,
                    onPickFromGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemoveSelectedAt: _removeSelectedImageAt,
                    onRemoveExistingAt: _removeExistingImageAt,
                    onReorderExisting: _reorderExistingImage,
                    onReorderSelected: _reorderSelectedImage,
                  ),
                  const SizedBox(height: 16),

                  // Name and Description
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextField(
                            controller: _nameController,
                            labelText: 'Spot Name',
                            hintText: 'Enter the name of the spot',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a spot name';
                              }
                              if (value.trim().length < 3) {
                                return 'Spot name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _descriptionController,
                            labelText: 'Description',
                            hintText: 'Describe the spot, what makes it special, etc.',
                            maxLines: 4,
                            validator: (value) {
                              // Moderators can save spots without descriptions
                              final isModeratorOrAdmin = authService.isModerator || authService.isAdmin;
                              
                              if (!isModeratorOrAdmin) {
                                // For non-moderators, description is required
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a description';
                                }
                                if (value.trim().length < 10) {
                                  return 'Description must be at least 10 characters';
                                }
                              }
                              // For moderators, description is optional
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attributes Section
                  SpotAttributesSection(
                    selectedAccess: _selectedAccess,
                    selectedFeatures: _selectedFeatures,
                    selectedFacilities: _selectedFacilities,
                    selectedGoodFor: _selectedGoodFor,
                    onAccessChanged: _onAccessChanged,
                    onToggleFeature: _toggleFeature,
                    onFacilityChanged: _onFacilityChanged,
                    onToggleGoodFor: _toggleGoodFor,
                  ),
                  const SizedBox(height: 16),

                  // YouTube Links Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'YouTube Links',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addYoutubeLink,
                                tooltip: 'Add YouTube link',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter YouTube video IDs or URLs (e.g., dQw4w9WgXcQ or https://www.youtube.com/watch?v=dQw4w9WgXcQ)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          if (_youtubeControllers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'No YouTube links added. Click the + button to add one.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            ...List.generate(
                              _youtubeControllers.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        controller: _youtubeControllers[index],
                                        labelText: 'YouTube Link ${index + 1}',
                                        hintText: 'Enter YouTube video ID or URL',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle),
                                      color: Colors.red,
                                      onPressed: () => _removeYoutubeLink(index),
                                      tooltip: 'Remove YouTube link',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Moderator Action Fields
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Moderator Notes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Optionally link this edit to a spot report and add notes for the audit log.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ModeratorActionFields(
                            spotId: widget.spot.id,
                            notesController: _notesController,
                            showReportSelector: true,
                            onReportSelected: (reportId) {
                              setState(() {
                                _selectedReportId = reportId;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  CustomButton(
                    onPressed: _isLoading ? null : _saveSpot,
                    text: _isLoading ? 'Saving...' : 'Update Spot',
                    icon: Icons.save,
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
