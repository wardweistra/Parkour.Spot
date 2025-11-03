import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:math';
import '../models/spot.dart';
import '../models/rating.dart';

class SpotService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get spots by location (within radius) - Modern efficient approach
  Future<List<Spot>> getSpotsNearby(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      // Calculate bounding box for the search area
      final bounds = _calculateBoundingBox(latitude, longitude, radiusKm);
      
      // Use the dateline-aware getSpotsInBounds method
      final candidates = await getSpotsInBounds(
        bounds['minLat']!,
        bounds['maxLat']!,
        bounds['minLng']!,
        bounds['maxLng']!,
      );
      
      // Filter by actual distance (smaller dataset now)
      return candidates.where((spot) {
        final distance = _calculateDistance(
          latitude,
          longitude,
        spot.latitude,
        spot.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      debugPrint('Error getting nearby spots: $e');
      return [];
    }
  }

  // Get a single spot by ID
  Future<Spot?> getSpotById(String spotId) async {
    try {
      final doc = await _firestore.collection('spots').doc(spotId).get();
      if (doc.exists) {
        return Spot.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching spot by ID: $e');
      return null;
    }
  }

  // Create a new spot
  Future<String?> createSpot(Spot spot, {File? imageFile, Uint8List? imageBytes, List<File>? imageFiles, List<Uint8List>? imageBytesList}) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<String>? imageUrls;
      
      // Handle single image uploads
      if (imageFile != null) {
        final imageUrl = await _uploadImage(imageFile);
        imageUrls = [imageUrl];
      } else if (imageBytes != null) {
        final imageUrl = await _uploadImageBytes(imageBytes);
        imageUrls = [imageUrl];
      }
      
      // Handle multiple image uploads
      if (imageFiles != null && imageFiles.isNotEmpty) {
        imageUrls = await _uploadImages(imageFiles);
      } else if (imageBytesList != null && imageBytesList.isNotEmpty) {
        imageUrls = await _uploadImagesBytes(imageBytesList);
      }

      final spotWithImages = spot.copyWith(
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ranking: spot.ranking ?? Random().nextDouble(),
      );

      final docRef = await _firestore.collection('spots').add(spotWithImages.toFirestore());
      
      return docRef.id; // Return the spot ID
    } catch (e) {
      _error = 'Failed to create spot: $e';
      debugPrint('Error creating spot: $e');
      return null; // Return null on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enhanced update method for comprehensive spot updates
  Future<bool> updateSpotComplete(
    Spot spot, 
    {
      List<File>? newImageFiles,
      List<Uint8List>? newImageBytesList,
      List<String>? imagesToDelete,
    }
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<String>? imageUrls = List.from(spot.imageUrls ?? []);

      // Remove images to delete
      if (imagesToDelete != null && imagesToDelete.isNotEmpty) {
        for (final imageUrl in imagesToDelete) {
          await deleteImageFromStorage(imageUrl);
          imageUrls.remove(imageUrl);
        }
      }

      // Add new images
      if (newImageFiles != null && newImageFiles.isNotEmpty) {
        final uploadedUrls = await _uploadImages(newImageFiles);
        imageUrls.addAll(uploadedUrls);
      }

      if (newImageBytesList != null && newImageBytesList.isNotEmpty) {
        final uploadedUrls = await _uploadImagesBytes(newImageBytesList);
        imageUrls.addAll(uploadedUrls);
      }

      final updatedSpot = spot.copyWith(
        imageUrls: imageUrls,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('spots').doc(spot.id).update(updatedSpot.toFirestore());
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating spot: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete specific image from storage
  Future<bool> deleteImageFromStorage(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting image from storage: $e');
      return false;
    }
  }

  // Update an existing spot (legacy method)
  Future<bool> updateSpot(Spot spot, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<String>? imageUrls = spot.imageUrls;
      if (imageFile != null) {
        final imageUrl = await _uploadImage(imageFile);
        imageUrls = [
          ...?spot.imageUrls,
          imageUrl,
        ];
      } else if (imageBytes != null) {
        final imageUrl = await _uploadImageBytes(imageBytes);
        imageUrls = [
          ...?spot.imageUrls,
          imageUrl,
        ];
      }

      final updatedSpot = spot.copyWith(
        imageUrls: imageUrls,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('spots').doc(spot.id).update(updatedSpot.toFirestore());
      
      return true;
    } catch (e) {
      _error = 'Failed to update spot: $e';
      debugPrint('Error updating spot: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a spot
  Future<bool> deleteSpot(String spotId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('spots').doc(spotId).delete();
      
      return true;
    } catch (e) {
      _error = 'Failed to delete spot: $e';
      debugPrint('Error deleting spot: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  // Upload single image to Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    try {
      final fileName = 'spots/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child(fileName);
      
      // Detect MIME type from file extension
      final contentType = _getMimeTypeFromExtension(imageFile.path);
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: contentType),
      );
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // Upload image bytes to Firebase Storage (for web)
  Future<String> _uploadImageBytes(Uint8List imageBytes) async {
    try {
      final fileName = 'spots/${DateTime.now().millisecondsSinceEpoch}_web_image.jpg';
      final ref = _storage.ref().child(fileName);
      
      // Detect MIME type from image bytes
      final contentType = _detectImageMimeType(imageBytes);
      
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: contentType),
      );
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image bytes: $e');
      rethrow;
    }
  }

  // Upload multiple images to Firebase Storage
  Future<List<String>> _uploadImages(List<File> imageFiles) async {
    final List<String> imageUrls = [];
    for (final imageFile in imageFiles) {
      final imageUrl = await _uploadImage(imageFile);
      imageUrls.add(imageUrl);
    }
    return imageUrls;
  }

  // Upload multiple image bytes to Firebase Storage (for web)
  Future<List<String>> _uploadImagesBytes(List<Uint8List> imageBytesList) async {
    final List<String> imageUrls = [];
    for (final imageBytes in imageBytesList) {
      final imageUrl = await _uploadImageBytes(imageBytes);
      imageUrls.add(imageUrl);
    }
    return imageUrls;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
               (sin(lat1) * sin(lat2) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  // Detect MIME type from image bytes by checking magic numbers
  String _detectImageMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg'; // Default fallback
    
    // Check for JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    
    // Check for PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    
    // Check for GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }
    
    // Check for WebP
    if (bytes.length >= 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    
    // Default to JPEG if we can't detect the type
    return 'image/jpeg';
  }

  // Get MIME type from file extension
  String _getMimeTypeFromExtension(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  // Calculate bounding box for geo queries
  Map<String, double> _calculateBoundingBox(
    double latitude, 
    double longitude, 
    double radiusKm
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    // Convert radius to degrees
    final latDelta = radiusKm / earthRadius * (180 / 3.14159265359);
    final lngDelta = radiusKm / (earthRadius * cos(latitude * 3.14159265359 / 180)) * (180 / 3.14159265359);
    
    return {
      'minLat': latitude - latDelta,
      'maxLat': latitude + latDelta,
      'minLng': longitude - lngDelta,
      'maxLng': longitude + lngDelta,
    };
  }

  // Rate a spot
  Future<bool> rateSpot(String spotId, double rating, String userId) async {
    try {
      // Check if user has already rated this spot
      if (userId.isEmpty) {
        debugPrint('User ID is required for rating');
        return false;
      }
      
      // Check if user already rated this spot
      final existingRatingDoc = await _firestore
          .collection('ratings')
          .where('spotId', isEqualTo: spotId)
          .where('userId', isEqualTo: userId)
          .get();
      
      if (existingRatingDoc.docs.isNotEmpty) {
        // Update existing rating
        final ratingDoc = existingRatingDoc.docs.first;
        await ratingDoc.reference.update({
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new rating
        await _firestore.collection('ratings').add({
          'spotId': spotId,
          'userId': userId,
          'rating': rating,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      return true;
    } catch (e) {
      debugPrint('Error rating spot: $e');
      return false;
    }
  }

  // Get user's rating for a specific spot
  Future<double?> getUserRating(String spotId, String userId) async {
    try {
      final ratingDoc = await _firestore
          .collection('ratings')
          .where('spotId', isEqualTo: spotId)
          .where('userId', isEqualTo: userId)
          .get();
      
      if (ratingDoc.docs.isNotEmpty) {
        return ratingDoc.docs.first.data()['rating'] as double?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user rating: $e');
      return null;
    }
  }

  // Get all ratings for a specific spot
  Future<List<Rating>> getSpotRatings(String spotId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('spotId', isEqualTo: spotId)
          .get();
      
      return ratingsSnapshot.docs
          .map((doc) => Rating.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting spot ratings: $e');
      return [];
    }
  }

  // Get calculated rating statistics for a spot using cached aggregates
  Future<Map<String, dynamic>> getSpotRatingStats(String spotId) async {
    try {
      // All spots now have cached rating aggregates, so we can rely on them directly
      final doc = await _firestore.collection('spots').doc(spotId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final avg = (data['averageRating'] ?? 0).toDouble();
        final count = (data['ratingCount'] ?? 0) as int;
        
        return {
          'averageRating': avg,
          'ratingCount': count,
          'ratingDistribution': <int, int>{}, // optional, not stored
        };
      }

      // Fallback to zeros if spot doesn't exist (shouldn't happen)
      return {
        'averageRating': 0.0,
        'ratingCount': 0,
        'ratingDistribution': <int, int>{},
      };
    } catch (e) {
      debugPrint('Error getting spot rating stats: $e');
      return {
        'averageRating': 0.0,
        'ratingCount': 0,
        'ratingDistribution': <int, int>{},
      };
    }
  }

  // Admin: Recompute rating aggregates for all spots that have ratings
  Future<Map<String, dynamic>> recomputeAllRatedSpots() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'recomputeAllRatedSpots',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Error recomputing all rated spots: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recomputeSpotRankings() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'recomputeSpotRankings',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Error recomputing spot rankings: $e');
      rethrow;
    }
  }

  // Get spots with pagination for large result sets
  Future<List<Spot>> getSpotsNearbyPaginated(
    double latitude,
    double longitude,
    double radiusKm, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final bounds = _calculateBoundingBox(latitude, longitude, radiusKm);
      
      // For pagination with dateline crossing, we need to handle it differently
      // For now, use the non-paginated approach and apply pagination after filtering
      final candidates = await getSpotsInBounds(
        bounds['minLat']!,
        bounds['maxLat']!,
        bounds['minLng']!,
        bounds['maxLng']!,
      );
      
      // Filter by actual distance and sort by distance
      final filteredSpots = candidates.where((spot) {
        final distance = _calculateDistance(
          latitude,
          longitude,
        spot.latitude,
        spot.longitude,
        );
        return distance <= radiusKm;
      }).toList();
      
      // Sort by distance
      filteredSpots.sort((a, b) {
        final distanceA = _calculateDistance(
          latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(
          latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      
      return filteredSpots;
    } catch (e) {
      debugPrint('Error getting nearby spots paginated: $e');
      return [];
    }
  }

  // Get spots within a specific area (useful for map bounds)
  Future<List<Spot>> getSpotsInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) async {
    try {
      debugPrint('🔍 SpotService.getSpotsInBounds called with bounds:');
      debugPrint('   minLat: $minLat, maxLat: $maxLat');
      debugPrint('   minLng: $minLng, maxLng: $maxLng');
      
      // Check if the bounds cross the dateline
      final crossesDateline = minLng > maxLng;
      debugPrint('🌍 Dateline crossing: $crossesDateline');
      
      List<Spot> allSpots = [];
      
      if (crossesDateline) {
        debugPrint('🌊 Handling dateline crossing with two queries');
        
        // Query 1: From minLng to 180
        final query1 = await _firestore
            .collection('spots')
            .where('isPublic', isEqualTo: true)
            .orderBy('longitude')
            .where('latitude', isGreaterThanOrEqualTo: minLat)
            .where('latitude', isLessThanOrEqualTo: maxLat)
            .where('longitude', isGreaterThanOrEqualTo: minLng)
            .where('longitude', isLessThanOrEqualTo: 180)
            .orderBy('latitude')
            .get();
        
        debugPrint('📊 Query 1 ($minLng to 180): ${query1.docs.length} documents');
        
        // Query 2: From -180 to maxLng
        final query2 = await _firestore
            .collection('spots')
            .where('isPublic', isEqualTo: true)
            .orderBy('longitude')
            .where('latitude', isGreaterThanOrEqualTo: minLat)
            .where('latitude', isLessThanOrEqualTo: maxLat)
            .where('longitude', isGreaterThanOrEqualTo: -180)
            .where('longitude', isLessThanOrEqualTo: maxLng)
            .orderBy('latitude')
            .get();
        
        debugPrint('📊 Query 2 (-180 to $maxLng): ${query2.docs.length} documents');
        
        // Combine results
        allSpots = [
          ...query1.docs.map((doc) => Spot.fromFirestore(doc)),
          ...query2.docs.map((doc) => Spot.fromFirestore(doc)),
        ];
        
        debugPrint('📊 Total combined results: ${allSpots.length} documents');
      } else {
        debugPrint('🌍 Normal query (no dateline crossing)');
        
        final querySnapshot = await _firestore
            .collection('spots')
            .where('isPublic', isEqualTo: true)
            .orderBy('longitude')
            .where('latitude', isGreaterThanOrEqualTo: minLat)
            .where('latitude', isLessThanOrEqualTo: maxLat)
            .where('longitude', isGreaterThanOrEqualTo: minLng)
            .where('longitude', isLessThanOrEqualTo: maxLng)
            .orderBy('latitude')
            .get();
        
        debugPrint('📊 Firestore query executed:');
        debugPrint('   - Collection: spots');
        debugPrint('   - isPublic: true');
        debugPrint('   - latitude range: $minLat to $maxLat (field: latitude)');
        debugPrint('   - longitude range: $minLng to $maxLng (field: longitude)');
        debugPrint('   - Documents returned: ${querySnapshot.docs.length}');
        
        allSpots = querySnapshot.docs
            .map((doc) => Spot.fromFirestore(doc))
            .toList();
      }
      
      if (allSpots.isEmpty) {
        debugPrint('⚠️ No documents found in Firestore for these bounds');
      } else {
        debugPrint('✅ Found ${allSpots.length} documents');
        for (int i = 0; i < allSpots.length && i < 3; i++) {
          final spot = allSpots[i];
          debugPrint('   Spot $i: ${spot.name}');
          debugPrint('     - latitude: ${spot.latitude}');
          debugPrint('     - longitude: ${spot.longitude}');
          debugPrint('     - isPublic: ${spot.isPublic}');
        }
      }
      
      debugPrint('🎯 Converted to ${allSpots.length} Spot objects');
      
      return allSpots;
    } catch (e) {
      debugPrint('❌ Error getting spots in bounds: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get top ranked spots within bounds using backend Wilson logic
  Future<Map<String, dynamic>> getTopRankedSpotsInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int limit = 100,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('getTopSpotsInBounds');
      final result = await callable.call({
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
        'limit': limit,
      });

      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(data != null && data['error'] is String ? data['error'] : 'Unknown error');
      }

      final List<dynamic> items = (data['spots'] as List<dynamic>? ?? <dynamic>[]);
      final spots = items
          .whereType<Map<String, dynamic>>()
          .map((m) => Spot.fromMap(m))
          .toList();

      return {
        'spots': spots,
        'totalCount': (data['totalCount'] as num?)?.toInt() ?? spots.length,
        'shownCount': (data['shownCount'] as num?)?.toInt() ?? spots.length,
        'averageWilson': (data['averageWilson'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting top ranked spots in bounds: $e');
      return {'spots': <Spot>[], 'totalCount': 0, 'shownCount': 0, 'averageWilson': 0.0};
    }
  }

  // Load spots for map view with loading state management
  Future<List<Spot>> loadSpotsForMapView(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) async {
    try {
      debugPrint('🗺️ SpotService.loadSpotsForMapView called with bounds:');
      debugPrint('   minLat: $minLat, maxLat: $maxLat');
      debugPrint('   minLng: $minLng, maxLng: $maxLng');
      
      _isLoading = true;
      _error = null;
      notifyListeners();

      final spots = await getSpotsInBounds(minLat, maxLat, minLng, maxLng);
      
      debugPrint('📍 SpotService.loadSpotsForMapView retrieved ${spots.length} spots');
      if (spots.isNotEmpty) {
        debugPrint('   First spot: ${spots.first.name} at (${spots.first.latitude}, ${spots.first.longitude})');
      }
      
      return spots;
    } catch (e) {
      _error = 'Failed to load spots for map view: $e';
      debugPrint('❌ Error loading spots for map view: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  // Get spots by source and timestamp (admin function)
  Future<List<Spot>> getSpotsBySourceAndTimestamp(
    String sourceId,
    DateTime timestamp,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('🔍 Searching spots for source: $sourceId');
      debugPrint('📅 Last updated before: $timestamp');

      Query query = _firestore.collection('spots');

      // Filter by source
      if (sourceId.isNotEmpty) {
        query = query.where('spotSource', isEqualTo: sourceId);
      } else {
        // If sourceId is empty, get spots with no source (native spots)
        query = query.where('spotSource', isNull: true);
      }

      // Filter by last updated date - spots updated before the selected timestamp
      query = query
          .where('updatedAt', isLessThan: Timestamp.fromDate(timestamp))
          .orderBy('updatedAt', descending: true);

      final querySnapshot = await query.get();
      
      final spots = querySnapshot.docs
          .map((doc) => Spot.fromFirestore(doc))
          .toList();

      debugPrint('✅ Found ${spots.length} spots for source $sourceId last updated before ${timestamp.day}/${timestamp.month}/${timestamp.year}');

      return spots;
    } catch (e) {
      _error = 'Failed to fetch spots by source and timestamp: $e';
      debugPrint('Error fetching spots by source and timestamp: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete multiple spots (admin function)
  Future<Map<String, int>> deleteSpots(List<String> spotIds) async {
    try {
      _isLoading = true;
      notifyListeners();

      int deletedCount = 0;
      int failedCount = 0;

      for (final spotId in spotIds) {
        try {
          await _firestore.collection('spots').doc(spotId).delete();
          deletedCount++;
          debugPrint('✅ Deleted spot: $spotId');
        } catch (e) {
          failedCount++;
          debugPrint('❌ Failed to delete spot $spotId: $e');
        }
      }

      return {
        'deleted': deletedCount,
        'failed': failedCount,
      };
    } catch (e) {
      _error = 'Failed to delete spots: $e';
      debugPrint('Error deleting spots: $e');
      return {'deleted': 0, 'failed': spotIds.length};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search spots for duplicate selection (excludes duplicates and specified spot)
  Future<List<Spot>> searchSpotsForDuplicateSelection({
    String? excludeSpotId,
    String? query,
    int limit = 1000,
  }) async {
    try {
      Query queryRef = _firestore
          .collection('spots')
          .where('isPublic', isEqualTo: true)
          .where('duplicateOf', isNull: true); // Exclude spots that are already duplicates

      final querySnapshot = await queryRef.limit(limit).get();

      final spots = querySnapshot.docs
          .map((doc) => Spot.fromFirestore(doc))
          .where((spot) => spot.id != excludeSpotId) // Exclude specified spot
          .toList();

      // If query is provided, filter by name, description, address, or city
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        spots.retainWhere((spot) {
          final nameMatch = spot.name.toLowerCase().contains(queryLower);
          final descriptionMatch = spot.description.toLowerCase().contains(queryLower);
          final addressMatch = spot.address?.toLowerCase().contains(queryLower) ?? false;
          final cityMatch = spot.city?.toLowerCase().contains(queryLower) ?? false;
          return nameMatch || descriptionMatch || addressMatch || cityMatch;
        });
      }

      return spots;
    } catch (e) {
      debugPrint('Error searching spots for duplicate selection: $e');
      return [];
    }
  }

  // Mark a spot as duplicate of another spot
  Future<bool> markSpotAsDuplicate(String spotId, String originalSpotId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Verify that the original spot exists and is not a duplicate itself
      final originalSpot = await getSpotById(originalSpotId);
      if (originalSpot == null) {
        _error = 'Original spot not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Prevent marking a spot as duplicate of itself
      if (spotId == originalSpotId) {
        _error = 'Cannot mark a spot as duplicate of itself';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Prevent circular references (check if original is already marked as duplicate)
      if (originalSpot.duplicateOf != null) {
        _error = 'Cannot mark as duplicate of a spot that is already a duplicate';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Ensure the original spot is a native parkour.spot spot (not from external source)
      if (originalSpot.spotSource != null) {
        _error = 'Original spot must be a native parkour.spot spot, not from an external source';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update the spot to mark it as duplicate
      await _firestore.collection('spots').doc(spotId).update({
        'duplicateOf': originalSpotId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to mark spot as duplicate: $e';
      debugPrint('Error marking spot as duplicate: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get all spots that are duplicates of a given spot
  Future<List<Spot>> getDuplicatesOfSpot(String spotId) async {
    try {
      final querySnapshot = await _firestore
          .collection('spots')
          .where('duplicateOf', isEqualTo: spotId)
          .get();

      return querySnapshot.docs
          .map((doc) => Spot.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting duplicates of spot: $e');
      return [];
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
