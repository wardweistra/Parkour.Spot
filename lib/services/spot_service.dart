import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math';
import '../models/spot.dart';
import '../models/rating.dart';
import '../utils/geohash_utils.dart';

class SpotService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<Spot> _spots = [];
  bool _isLoading = false;
  String? _error;

  List<Spot> get spots => _spots;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all spots
  Future<void> fetchSpots() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('spots')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      _spots = querySnapshot.docs
          .map((doc) => Spot.fromFirestore(doc))
          .toList();

    } catch (e) {
      _error = 'Failed to fetch spots: $e';
      debugPrint('Error fetching spots: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get spots by location (within radius)
  Future<List<Spot>> getSpotsNearby(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      // Firestore doesn't support native geospatial queries
      // We'll fetch all spots and filter by distance
      await fetchSpots();
      
      return _spots.where((spot) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          spot.location.latitude,
          spot.location.longitude,
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
      // First check if we have it in local cache
      final localSpot = _spots.firstWhere(
        (spot) => spot.id == spotId,
        orElse: () => throw Exception('Spot not found locally'),
      );
      return localSpot;
    } catch (e) {
      // If not in local cache, fetch from Firestore
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

      // Calculate geohash for the spot location
      final geohash = GeohashUtils.calculateGeohashFromGeoPoint(spot.location);

      final spotWithImages = spot.copyWith(
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        geohash: geohash,
      );

      final docRef = await _firestore.collection('spots').add(spotWithImages.toFirestore());
      
      // Add the new spot to the local list
      final newSpot = spotWithImages.copyWith(id: docRef.id);
      _spots.insert(0, newSpot);
      
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

      // Recalculate geohash if location might have changed
      final geohash = GeohashUtils.calculateGeohashFromGeoPoint(spot.location);

      final updatedSpot = spot.copyWith(
        imageUrls: imageUrls,
        updatedAt: DateTime.now(),
        geohash: geohash,
      );

      await _firestore.collection('spots').doc(spot.id).update(updatedSpot.toFirestore());
      
      // Update the spot in the local list
      final index = _spots.indexWhere((s) => s.id == spot.id);
      if (index != -1) {
        _spots[index] = updatedSpot;
      }
      
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
      
      // Remove the spot from the local list
      _spots.removeWhere((spot) => spot.id == spotId);
      
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

  // Get calculated rating statistics for a spot
  Future<Map<String, dynamic>> getSpotRatingStats(String spotId) async {
    try {
      final ratings = await getSpotRatings(spotId);
      
      if (ratings.isEmpty) {
        return {
          'averageRating': 0.0,
          'ratingCount': 0,
          'ratingDistribution': <int, int>{},
        };
      }
      
      double totalRating = 0;
      Map<int, int> ratingDistribution = {};
      
      for (final rating in ratings) {
        totalRating += rating.rating;
        final ratingInt = rating.rating.toInt();
        ratingDistribution[ratingInt] = (ratingDistribution[ratingInt] ?? 0) + 1;
      }
      
      final averageRating = totalRating / ratings.length;
      
      return {
        'averageRating': averageRating,
        'ratingCount': ratings.length,
        'ratingDistribution': ratingDistribution,
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

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
