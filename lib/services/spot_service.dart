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
        random: spot.random ?? Random().nextDouble(),
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

  // Update an existing spot
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
      
      final uploadTask = ref.putFile(imageFile);
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
      
      final uploadTask = ref.putData(imageBytes);
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


  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
