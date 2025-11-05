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

    if (_existingImageUrls.isEmpty && _selectedImageBytes.every((bytes) => bytes == null)) {
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

      // Create updated spot data
      final updatedSpot = widget.spot.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.toList(),
        spotFacilities: _selectedFacilities,
        goodFor: _selectedGoodFor.toList(),
        updatedAt: DateTime.now(),
      );

      // Filter out null values for images
      final validNewImageBytes = _selectedImageBytes.where((bytes) => bytes != null).cast<Uint8List>().toList();

      final success = await spotService.updateSpotComplete(
        updatedSpot,
        newImageFiles: null,
        newImageBytesList: validNewImageBytes.isNotEmpty ? validNewImageBytes : null,
        imagesToDelete: _imagesToDelete.isNotEmpty ? _imagesToDelete : null,
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
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a description';
                              }
                              if (value.trim().length < 10) {
                                return 'Description must be at least 10 characters';
                              }
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
