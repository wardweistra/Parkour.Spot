import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/search_state_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/attributes_section.dart';
import '../../screens/spots/location_picker_screen.dart';
import '../../utils/map_recentering_mixin.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeForm();
    
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
    for (final controller in _youtubeControllers) {
      controller.dispose();
    }
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        // Center the map on the new current location with a small delay to ensure controller is ready
        centerMapOnLocationWithDelay(LatLng(position.latitude, position.longitude));
        await _geocodeLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
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
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        if (kIsWeb) {
          final List<Uint8List> bytesList = [];
          for (final image in images) {
            final bytes = await image.readAsBytes();
            bytesList.add(bytes);
          }
          if (mounted) {
            setState(() {
              _selectedImageBytes.addAll(bytesList);
            });
          }
        } else {
          setState(() {
            for (final image in images) {
              // For web, read the bytes directly
              image.readAsBytes().then((bytes) {
                setState(() {
                  _selectedImageBytes.add(bytes);
                });
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          if (mounted) {
            setState(() {
              _selectedImageBytes.add(bytes);
            });
          }
        } else {
          setState(() {
            // For web, read the bytes directly
            image.readAsBytes().then((bytes) {
              setState(() {
                _selectedImageBytes.add(bytes);
              });
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
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
      _imagesToDelete.add(imageUrl);
      _existingImageUrls.removeAt(index);
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

  void _clearDuplicateOf() {
    setState(() {
      _duplicateOf = null;
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

      // Create updated spot data
      final updatedSpot = widget.spot.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        youtubeVideoIds: youtubeIds.isNotEmpty ? youtubeIds : null,
        duplicateOf: _duplicateOf,
        spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.toList(),
        spotFacilities: _selectedFacilities,
        goodFor: _selectedGoodFor.toList(),
        updatedAt: DateTime.now(),
      );

      // Filter out null values for images
      final validNewImageBytes = _selectedImageBytes.where((bytes) => bytes != null).cast<Uint8List>().toList();

      // Get user info for audit logging (moderator edits)
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final userName = authService.userProfile?.displayName ?? authService.currentUser?.displayName ?? authService.currentUser?.email;

      final success = await spotService.updateSpot(
        updatedSpot,
        newImageFiles: null,
        newImageBytesList: validNewImageBytes.isNotEmpty ? validNewImageBytes : null,
        imagesToDelete: _imagesToDelete.isNotEmpty ? _imagesToDelete : null,
        userId: userId,
        userName: userName,
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Spot'),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location Section
                  SpotLocationSection(
                    currentLocation: _currentLocation,
                    address: _currentAddress,
                    isGettingLocation: _isGettingLocation,
                    isGeocoding: _isGeocoding,
                    isSatelliteView: _isSatelliteView,
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

                  // Duplicate Section
                  if (_duplicateOf != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duplicate Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This spot is marked as a duplicate of: $_duplicateOf',
                              style: const TextStyle(color: Colors.orange),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _clearDuplicateOf,
                              icon: const Icon(Icons.clear),
                              label: const Text('Remove Duplicate Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

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
        );
      },
    );
  }
}
