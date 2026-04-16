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
import '../../services/search_state_service.dart';
import '../../services/url_service.dart';
import '../../utils/location_permission_utils.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/attributes_section.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';
import 'package:go_router/go_router.dart';
import '../../utils/map_recentering_mixin.dart';
import '../../utils/image_preparation.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';

class AddSpotScreen extends StatefulWidget {
  final LatLng? initialLocation;
  
  const AddSpotScreen({super.key, this.initialLocation});

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
  bool _isLocationPermissionDenied = false;
  SearchStateService? _searchStateServiceRef;
  
  // Spot attributes
  String? _selectedAccess;
  final Set<String> _selectedFeatures = <String>{};
  final Map<String, String> _selectedFacilities = <String, String>{};
  final Set<String> _selectedGoodFor = <String>{};

  @override
  void initState() {
    super.initState();
    
    // If initial location is provided, use it; otherwise get current location
    if (widget.initialLocation != null) {
      setState(() {
        _pickedLocation = widget.initialLocation;
      });
      // Geocode the initial location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _geocodeLocation(widget.initialLocation!.latitude, widget.initialLocation!.longitude);
      });
    } else {
      // Set default location so map is always visible, even if permission is denied
      setState(() {
        _pickedLocation = const LatLng(AppConfig.defaultMapCenterLat, AppConfig.defaultMapCenterLng);
      });
      // Geocode the default location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _geocodeLocation(AppConfig.defaultMapCenterLat, AppConfig.defaultMapCenterLng);
      });
      // Try to get current location, but don't block if permission is denied
      _getCurrentLocation();
    }
    
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
    if (_currentPosition != null || _pickedLocation != null) {
      final target = _pickedLocation ?? LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      centerMapAfterBuild(target);
    }
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
        // If permission denied, ensure we still have a default location for the map
        if (_pickedLocation == null && _currentPosition == null) {
          setState(() {
            _pickedLocation = const LatLng(AppConfig.defaultMapCenterLat, AppConfig.defaultMapCenterLng);
          });
          // Geocode the default location
          _geocodeLocation(AppConfig.defaultMapCenterLat, AppConfig.defaultMapCenterLng);
        }
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
          _currentPosition = position;
          // Clear picked location so map shows current location instead
          _pickedLocation = null;
          _isLocationPermissionDenied = false;
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
            content: Text(AppLocalizations.of(context)!.exploreLocationError('$e')),
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
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        int added = 0;
        for (final pickedFile in pickedFiles) {
          try {
            final bytes = await pickedFile.readAsBytes();
            final prepared = await prepareImageForUpload(bytes);
            _selectedImageBytes.add(prepared.bytes);
            added++;
          } on ImagePreparationException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        if (added > 0) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ImagePreparationException
                  ? e.message
                  : AppLocalizations.of(context)!.addSpotPickImagesFailed,
            ),
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
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        _selectedImageBytes.add(prepared.bytes);
        setState(() {});
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.addSpotTakePhotoFailed),
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

  void _reorderSelectedImage(int oldIndex, int newIndex) {
    setState(() {
      final item = _selectedImageBytes.removeAt(oldIndex);
      _selectedImageBytes.insert(newIndex, item);
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
          showUsageTip: true,
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addSpotNeedPhoto),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_currentPosition == null && _pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addSpotNeedLocation),
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

      // Create spot - resolve createdByName (prefer profile displayName, then Auth displayName, then email)
      final displayName = authService.userProfile?.displayName ??
          authService.currentUser?.displayName;
      final email = authService.currentUser?.email;
      final uid = authService.currentUser?.uid;
      final createdByName = displayName ?? email ?? uid ?? '';
      final spot = Spot(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _pickedLocation?.latitude ?? _currentPosition!.latitude,
        longitude: _pickedLocation?.longitude ?? _currentPosition!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        createdBy: authService.currentUser?.uid,
        createdByName: createdByName,
      averageRating: 0.0,
      ratingCount: 0,
      wilsonLowerBound: 0.0,
      ranking: Random().nextDouble(),
      spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.isNotEmpty ? _selectedFeatures.toList() : null,
        spotFacilities: _selectedFacilities.isNotEmpty ? _selectedFacilities : null,
        goodFor: _selectedGoodFor.isNotEmpty ? _selectedGoodFor.toList() : null,
        duplicateOf: null, // New spot, not a duplicate
        hidden: false, // New spot, not hidden
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
          // Use go so back from the new spot doesn't return to the add form
          context.go(navigationUrl);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.addSpotCreateError('$e')),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
              // Location Section
              SpotLocationSection(
                currentLocation: _pickedLocation != null 
                    ? LatLng(_pickedLocation!.latitude, _pickedLocation!.longitude)
                    : (_currentPosition != null 
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
                        : null),
                address: _currentAddress,
                countryCode: _currentCountryCode,
                isGettingLocation: _isGettingLocation,
                isGeocoding: _isGeocoding,
                isSatelliteView: _isSatelliteView,
                isLocationPermissionDenied: _isLocationPermissionDenied,
                onRefreshLocation: _getCurrentLocation,
                onPickOnMap: _pickLocationOnMap,
                onToggleSatellite: (value) {
                                    setState(() {
                                      _isSatelliteView = value;
                                    });
                                    final searchState = Provider.of<SearchStateService>(context, listen: false);
                                    searchState.setSatellite(value);
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
                onReorderSelected: _reorderSelectedImage,
              ),
              
              const SizedBox(height: 16),
              
              // Name Field
              CustomTextField(
                controller: _nameController,
                labelText: l10n.addSpotNameLabel,
                prefixIcon: Icons.location_on,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.addSpotNameRequired;
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Description Field
              CustomTextField(
                controller: _descriptionController,
                labelText: l10n.addSpotDescriptionLabel,
                prefixIcon: Icons.description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.addSpotDescriptionRequired;
                  }
                  if (value.trim().length < 10) {
                    return l10n.addSpotDescriptionMinLength;
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
                text: _isLoading ? l10n.addSpotCreating : l10n.addSpotCreateButton,
                isLoading: _isLoading,
                icon: Icons.add_location,
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}