import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import 'dart:math';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/url_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/attributes_section.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';
import 'package:go_router/go_router.dart';
import '../../utils/map_recentering_mixin.dart';

class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> with MapRecenteringMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final List<Uint8List?> _selectedImageBytes = [];
  Position? _currentPosition;
  LatLng? _pickedLocation;
  String? _currentAddress;
  String? _currentCity;
  String? _currentCountryCode;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isGeocoding = false;
  bool _isSatelliteView = false;
  
  // Spot attributes
  String? _selectedAccess;
  final Set<String> _selectedFeatures = <String>{};
  final Map<String, String> _selectedFacilities = <String, String>{};
  final Set<String> _selectedGoodFor = <String>{};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Center map on location after the map controller is created
    if (_currentPosition != null || _pickedLocation != null) {
      final target = _pickedLocation ?? LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      centerMapAfterBuild(target);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Clear picked location so map shows current location instead
          _pickedLocation = null;
        });
        // Center the map on the new current location with a small delay to ensure controller is ready
        centerMapOnLocationWithDelay(LatLng(position.latitude, position.longitude));
        // Geocode the coordinates to get address
        _geocodeCurrentLocation();
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

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        for (final pickedFile in pickedFiles) {
          // For web, read the bytes directly
          final bytes = await pickedFile.readAsBytes();
          _selectedImageBytes.add(bytes);
        }
        setState(() {}); // Force rebuild to show new images
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // For web, read the bytes directly
        final bytes = await pickedFile.readAsBytes();
        _selectedImageBytes.add(bytes);
        setState(() {}); // Force rebuild to show new images
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
    });
  }


  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _pickedLocation ?? 
              (_currentPosition != null 
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
                  : null),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _pickedLocation = result;
        // Clear current position so map shows picked location instead
        _currentPosition = null;
      });
      // Center the map on the new picked location with a small delay to ensure controller is ready
      centerMapOnLocationWithDelay(result);
      // Geocode the new coordinates to get address
      _geocodeLocation(result.latitude, result.longitude);
    }
  }

  Future<void> _geocodeCurrentLocation() async {
    if (_currentPosition == null) return;
      await _geocodeLocation(_currentPosition!.latitude, _currentPosition!.longitude);
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if at least one photo is uploaded
    if (_selectedImageBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one photo of the spot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_currentPosition == null && _pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location to be determined or pick a location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final spotService = Provider.of<SpotService>(context, listen: false);

      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Create spot
      final spot = Spot(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _pickedLocation?.latitude ?? _currentPosition!.latitude,
        longitude: _pickedLocation?.longitude ?? _currentPosition!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        createdBy: authService.currentUser?.uid,
        createdByName: authService.userProfile?.displayName ?? authService.currentUser?.email ?? authService.currentUser?.uid,
        averageRating: 0.0,
        ratingCount: 0,
        wilsonLowerBound: 0.0,
        random: Random().nextDouble(),
        ranking: Random().nextDouble(),
        spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.isNotEmpty ? _selectedFeatures.toList() : null,
        spotFacilities: _selectedFacilities.isNotEmpty ? _selectedFacilities : null,
        goodFor: _selectedGoodFor.isNotEmpty ? _selectedGoodFor.toList() : null,
      );

      final spotId = await spotService.createSpot(
        spot,
        imageFiles: null,
        imageBytesList: _selectedImageBytes.where((bytes) => bytes != null).cast<Uint8List>().toList(),
      );

      if (spotId != null && mounted) {
        // Clear form
        _nameController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedImageBytes.clear();
          _selectedAccess = null;
          _selectedFeatures.clear();
          _selectedFacilities.clear();
          _selectedGoodFor.clear();
        });
        
        // Navigate to the newly created spot detail page
        if (context.mounted) {
          // Use locale and city-based URL format
          final navigationUrl = UrlService.generateNavigationUrl(
            spotId, 
            countryCode: _currentCountryCode, 
            city: _currentCity
          );
          context.go(navigationUrl);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating spot: $e'),
            backgroundColor: Colors.red,
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Spot'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                currentLocation: _pickedLocation != null 
                    ? LatLng(_pickedLocation!.latitude, _pickedLocation!.longitude)
                    : (_currentPosition != null 
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
                        : null),
                address: _currentAddress,
                isGettingLocation: _isGettingLocation,
                isGeocoding: _isGeocoding,
                isSatelliteView: _isSatelliteView,
                onRefreshLocation: _getCurrentLocation,
                onPickOnMap: _pickLocationOnMap,
                onToggleSatellite: (value) {
                                    setState(() {
                                      _isSatelliteView = value;
                                    });
                                  },
                onMapCreated: onMapCreated,
              ),
              
              const SizedBox(height: 16),
              
              // Image Section
              SpotImageSection(
                selectedImageBytes: _selectedImageBytes,
                existingImageUrls: const <String>[],
                onPickFromGallery: _pickImagesFromGallery,
                onTakePhoto: _takePhoto,
                onRemoveSelectedAt: _removeImageAt,
                onRemoveExistingAt: (index) {}, // Not used in add mode
              ),
              
              const SizedBox(height: 16),
              
              // Name Field
              CustomTextField(
                controller: _nameController,
                labelText: 'Spot Name *',
                prefixIcon: Icons.location_on,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a spot name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Description Field
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description *',
                prefixIcon: Icons.description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
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
              
              const SizedBox(height: 16),
              
              // Attributes Section
              SpotAttributesSection(
                selectedAccess: _selectedAccess,
                selectedFeatures: _selectedFeatures,
                selectedFacilities: _selectedFacilities,
                selectedGoodFor: _selectedGoodFor,
                onAccessChanged: (value) {
                  setState(() {
                    _selectedAccess = value;
                  });
                },
                onToggleFeature: (key, selected) {
        setState(() {
                    if (selected) {
                      _selectedFeatures.add(key);
          } else {
                      _selectedFeatures.remove(key);
          }
        });
      },
                onFacilityChanged: (key, value) {
              setState(() {
                    _selectedFacilities[key] = value;
              });
            },
                onToggleGoodFor: (key, selected) {
        setState(() {
                    if (selected) {
                      _selectedGoodFor.add(key);
          } else {
                      _selectedGoodFor.remove(key);
          }
        });
        },
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              CustomButton(
                onPressed: _isLoading || 
                           (_currentPosition == null && _pickedLocation == null) || 
                           _selectedImageBytes.isEmpty 
                           ? null : _submitForm,
                text: _isLoading ? 'Creating Spot...' : 'Create Spot',
                isLoading: _isLoading,
                icon: Icons.add_location,
            ),
          ],
        ),
      ),
      ),
    );
  }
}