import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  List<File?> _selectedImages = [];
  List<Uint8List?> _selectedImageBytes = [];
  Position? _currentPosition;
  LatLng? _pickedLocation;
  String? _currentAddress;
  String? _currentCity;
  String? _currentCountryCode;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isGeocoding = false;
  GoogleMapController? _mapController;
  bool _isSatelliteView = false;
  
  // New spot attributes
  String? _selectedAccess;
  final Set<String> _selectedFeatures = <String>{};
  final Set<String> _selectedFacilities = <String>{};
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnLocation();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
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
        // Center the map on the new current location
        _centerMapOnLocation();
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
          if (kIsWeb) {
            // For web, read the bytes directly
            final bytes = await pickedFile.readAsBytes();
            _selectedImageBytes.add(bytes);
            _selectedImages.add(null); // No File object for web
          } else {
            // For mobile, use File
            _selectedImages.add(File(pickedFile.path));
            _selectedImageBytes.add(null);
          }
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
        if (kIsWeb) {
          // For web, read the bytes directly
          final bytes = await pickedFile.readAsBytes();
          _selectedImageBytes.add(bytes);
          _selectedImages.add(null); // No File object for web
        } else {
          // For mobile, use File
          _selectedImages.add(File(pickedFile.path));
          _selectedImageBytes.add(null);
        }
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
      if (index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      }
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
    });
  }

  Widget _buildCrossPlatformImage() {
    if (kIsWeb && _selectedImageBytes.isNotEmpty) {
      // For web, use Image.memory with bytes
      return SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImageBytes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _selectedImageBytes[index]!,
                    height: 200,
                    width: 280,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => _removeImageAt(index),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else if (!kIsWeb && _selectedImages.isNotEmpty) {
      // For mobile, use Image.file
      return SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImages[index]!,
                    height: 200,
                    width: 280,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => _removeImageAt(index),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // Fallback - no images selected
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 50,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'No photos selected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please add at least one photo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickLocationOnMap() async {
    final LatLng? initial = _pickedLocation ?? (
      _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null
    );

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _pickedLocation = result;
      });
      // Center the map on the newly picked location
      _centerMapOnLocation();
      // Geocode the picked location
      _geocodeLocation(result.latitude, result.longitude);
    }
  }

  void _centerMapOnLocation() {
    if (_mapController != null) {
      final LatLng? targetLocation = _pickedLocation ?? 
        (_currentPosition != null 
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : null);
      
      if (targetLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(targetLocation),
        );
      }
    }
  }

  Future<void> _geocodeCurrentLocation() async {
    if (_currentPosition != null) {
      await _geocodeLocation(_currentPosition!.latitude, _currentPosition!.longitude);
    }
  }

  Future<void> _geocodeLocation(double latitude, double longitude) async {
    setState(() {
      _isGeocoding = true;
    });

    try {
      final geocodingService = Provider.of<GeocodingService>(context, listen: false);
      final details = await geocodingService.geocodeCoordinatesDetailsSilently(latitude, longitude);
      
      if (mounted) {
        setState(() {
          _currentAddress = details['address'];
          _currentCity = details['city'];
          _currentCountryCode = details['countryCode'];
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error geocoding location: $e');
        // Don't show error to user as this is a background operation
      }
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
    if (_selectedImages.isEmpty && _selectedImageBytes.isEmpty) {
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

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Create spot
      final spot = Spot(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: _pickedLocation?.latitude ?? _currentPosition!.latitude,
        longitude: _pickedLocation?.longitude ?? _currentPosition!.longitude,
        address: _currentAddress,
        city: _currentCity,
        countryCode: _currentCountryCode,
        tags: tags.isNotEmpty ? tags : null,
        createdBy: authService.currentUser?.uid,
        createdByName: authService.userProfile?.displayName ?? authService.currentUser?.email ?? authService.currentUser?.uid,
        averageRating: 0.0,
        ratingCount: 0,
        wilsonLowerBound: 0.0,
        random: Random().nextDouble(),
        spotAccess: _selectedAccess,
        spotFeatures: _selectedFeatures.isNotEmpty ? _selectedFeatures.toList() : null,
        spotFacilities: _selectedFacilities.isNotEmpty ? _selectedFacilities.toList() : null,
        goodFor: _selectedGoodFor.isNotEmpty ? _selectedGoodFor.toList() : null,
      );

      final spotId = await spotService.createSpot(
        spot,
        imageFiles: _selectedImages.where((file) => file != null).cast<File>().toList(),
        imageBytesList: _selectedImageBytes.where((bytes) => bytes != null).cast<Uint8List>().toList(),
      );

      if (spotId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spot created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _formKey.currentState?.reset();
        setState(() {
          _selectedImages = [];
          _selectedImageBytes = [];
          _pickedLocation = null;
          _selectedAccess = null;
          _selectedFeatures.clear();
          _selectedFacilities.clear();
          _selectedGoodFor.clear();
        });
        
        // Navigate to the newly created spot detail page
        if (context.mounted) {
          context.go('/spot/$spotId');
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
              // Image Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Spot Images',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '*',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (_selectedImages.isNotEmpty || _selectedImageBytes.isNotEmpty) ...[
                        _buildCrossPlatformImage(),
                        const SizedBox(height: 12),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImagesFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              
              // Tags Field
              CustomTextField(
                controller: _tagsController,
                labelText: 'Tags (comma-separated)',
                prefixIcon: Icons.label,
                hintText: 'e.g., beginner, advanced, urban, natural',
              ),
              
              const SizedBox(height: 16),
              
              // Spot Access Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spot Access',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Public'),
                            subtitle: const Text('Open to everyone'),
                            value: 'Public',
                            groupValue: _selectedAccess,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedAccess = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            title: const Text('Restricted'),
                            subtitle: const Text('Limited access or permission required'),
                            value: 'Restricted',
                            groupValue: _selectedAccess,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedAccess = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            title: const Text('Paid'),
                            subtitle: const Text('Requires payment or membership'),
                            value: 'Paid',
                            groupValue: _selectedAccess,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedAccess = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Spot Features Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spot Features',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Walls
                      Text(
                        'Walls',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Low'),
                              value: _selectedFeatures.contains('Walls - Low'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Walls - Low');
                                  } else {
                                    _selectedFeatures.remove('Walls - Low');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Medium'),
                              value: _selectedFeatures.contains('Walls - Medium'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Walls - Medium');
                                  } else {
                                    _selectedFeatures.remove('Walls - Medium');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('High'),
                              value: _selectedFeatures.contains('Walls - High'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Walls - High');
                                  } else {
                                    _selectedFeatures.remove('Walls - High');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Bars
                      Text(
                        'Bars',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Low'),
                              value: _selectedFeatures.contains('Bars - Low'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Bars - Low');
                                  } else {
                                    _selectedFeatures.remove('Bars - Low');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Medium'),
                              value: _selectedFeatures.contains('Bars - Medium'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Bars - Medium');
                                  } else {
                                    _selectedFeatures.remove('Bars - Medium');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('High'),
                              value: _selectedFeatures.contains('Bars - High'),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFeatures.add('Bars - High');
                                  } else {
                                    _selectedFeatures.remove('Bars - High');
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Other features
                      Text(
                        'Other Features',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Climbing tree'),
                        value: _selectedFeatures.contains('Climbing tree'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFeatures.add('Climbing tree');
                            } else {
                              _selectedFeatures.remove('Climbing tree');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Rocks'),
                        value: _selectedFeatures.contains('Rocks'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFeatures.add('Rocks');
                            } else {
                              _selectedFeatures.remove('Rocks');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Soft landing pit'),
                        value: _selectedFeatures.contains('Soft landing pit'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFeatures.add('Soft landing pit');
                            } else {
                              _selectedFeatures.remove('Soft landing pit');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Spot Facilities Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spot Facilities',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Covered'),
                        subtitle: const Text('Protected from weather'),
                        value: _selectedFacilities.contains('Covered'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFacilities.add('Covered');
                            } else {
                              _selectedFacilities.remove('Covered');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Lighting'),
                        subtitle: const Text('Good lighting for evening sessions'),
                        value: _selectedFacilities.contains('Lighting'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFacilities.add('Lighting');
                            } else {
                              _selectedFacilities.remove('Lighting');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Water tap'),
                        subtitle: const Text('Access to drinking water'),
                        value: _selectedFacilities.contains('Water tap'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFacilities.add('Water tap');
                            } else {
                              _selectedFacilities.remove('Water tap');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Toilet'),
                        subtitle: const Text('Restroom facilities available'),
                        value: _selectedFacilities.contains('Toilet'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFacilities.add('Toilet');
                            } else {
                              _selectedFacilities.remove('Toilet');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Parking'),
                        subtitle: const Text('Parking available nearby'),
                        value: _selectedFacilities.contains('Parking'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFacilities.add('Parking');
                            } else {
                              _selectedFacilities.remove('Parking');
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Good For Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good For',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'What parkour skills can be practiced here?',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        children: [
                          'Vaults',
                          'Balance',
                          'Ascend',
                          'Decent',
                          'Speed run',
                          'Water challenges',
                          'Roof gap',
                          'Pole slide',
                        ].map((skill) {
                          return SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 24,
                            child: CheckboxListTile(
                              title: Text(skill),
                              value: _selectedGoodFor.contains(skill),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedGoodFor.add(skill);
                                  } else {
                                    _selectedGoodFor.remove(skill);
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_isGettingLocation) ...[
                        const Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 12),
                            Text('Getting your location...'),
                          ],
                        ),
                      ] else if (_pickedLocation != null) ...[
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
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${_pickedLocation!.latitude.toStringAsFixed(6)}, ${_pickedLocation!.longitude.toStringAsFixed(6)}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          if (_currentAddress != null) ...[
                                            TextSpan(
                                              text: '\n$_currentAddress',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_isGeocoding) ...[
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Getting address...',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Custom location selected',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (_currentPosition != null) ...[
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
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          if (_currentAddress != null) ...[
                                            TextSpan(
                                              text: '\n$_currentAddress',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_isGeocoding) ...[
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Getting address...',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.gps_fixed,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Location determined automatically',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_off,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Location not available',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Map preview
                      if (_pickedLocation != null || _currentPosition != null) ...[
                        const SizedBox(height: 16),
                        
                        // Map view toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location Preview',
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
                        
                        const SizedBox(height: 8),
                        
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _pickedLocation ?? LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              zoom: 16,
                            ),
                            mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            markers: {
                              Marker(
                                markerId: const MarkerId('selected_location'),
                                position: _pickedLocation ?? LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                infoWindow: InfoWindow(
                                  title: 'Selected Location',
                                  snippet: 'This is where your spot will be placed',
                                ),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            liteModeEnabled: kIsWeb,
                            compassEnabled: false,
                            // Disable map interactions for preview purposes
                            zoomGesturesEnabled: false,
                            scrollGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            onTap: (_) {
                              // Open location picker when tapping the map
                              _pickLocationOnMap();
                            },
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGettingLocation ? null : _getCurrentLocation,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Location'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickLocationOnMap,
                              icon: const Icon(Icons.map),
                              label: const Text('Pick on Map'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              CustomButton(
                onPressed: _isLoading || 
                           (_currentPosition == null && _pickedLocation == null) || 
                           (_selectedImages.isEmpty && _selectedImageBytes.isEmpty) 
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
