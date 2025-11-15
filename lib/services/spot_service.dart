import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:math';
import '../models/spot.dart';
import '../models/rating.dart';
import 'audit_log_service.dart';

class SpotService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuditLogService _auditLogService = AuditLogService();
  
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

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

  // Create a native spot from an existing spot (copies name, description, location, photos, youtube link)
  Future<String?> createNativeSpotFromExisting(Spot sourceSpot, String createdBy, String createdByName) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create a new native spot (no spotSource) with copied data
      final nativeSpot = Spot(
        name: sourceSpot.name,
        description: sourceSpot.description,
        latitude: sourceSpot.latitude,
        longitude: sourceSpot.longitude,
        address: sourceSpot.address,
        city: sourceSpot.city,
        countryCode: sourceSpot.countryCode,
        imageUrls: sourceSpot.imageUrls, // Preserve existing image URLs
        youtubeVideoIds: sourceSpot.youtubeVideoIds, // Preserve YouTube links
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        averageRating: 0.0,
        ratingCount: 0,
        wilsonLowerBound: 0.0,
        ranking: Random().nextDouble(),
        spotAccess: sourceSpot.spotAccess,
        spotFeatures: sourceSpot.spotFeatures,
        spotFacilities: sourceSpot.spotFacilities,
        goodFor: sourceSpot.goodFor,
        duplicateOf: null, // New native spot, not a duplicate
        // spotSource is null (native spot)
      );

      final docRef = await _firestore.collection('spots').add(nativeSpot.toFirestore());
      
      _isLoading = false;
      notifyListeners();
      return docRef.id; // Return the spot ID
    } catch (e) {
      _error = 'Failed to create native spot: $e';
      debugPrint('Error creating native spot: $e');
      _isLoading = false;
      notifyListeners();
      return null; // Return null on error
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
        duplicateOf: null, // New spot, not a duplicate
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

  // Update an existing spot with comprehensive image management
  Future<bool> updateSpot(
    Spot spot, 
    {
      List<File>? newImageFiles,
      List<Uint8List>? newImageBytesList,
      List<String>? imagesToDelete,
      String? userId,
      String? userName,
    }
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get the old spot data for audit logging
      Spot? oldSpot;
      if (userId != null && userName != null) {
        oldSpot = await getSpotById(spot.id!);
      }

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
      
      // Log audit trail if user info is provided (moderator edit)
      if (userId != null && userName != null && oldSpot != null) {
        final changes = _computeSpotChanges(oldSpot, updatedSpot);
        if (changes.isNotEmpty) {
          await _auditLogService.logSpotEdit(
            spotId: spot.id!,
            userId: userId,
            userName: userName,
            changes: changes,
          );
        }
      }
      
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

  // Compute changes between old and new spot for audit logging
  Map<String, dynamic> _computeSpotChanges(Spot oldSpot, Spot newSpot) {
    final changes = <String, dynamic>{};

    // Helper to compare values
    bool valuesEqual(dynamic oldVal, dynamic newVal) {
      if (oldVal == null && newVal == null) return true;
      if (oldVal == null || newVal == null) return false;
      if (oldVal is List && newVal is List) {
        if (oldVal.length != newVal.length) return false;
        for (int i = 0; i < oldVal.length; i++) {
          if (oldVal[i] != newVal[i]) return false;
        }
        return true;
      }
      if (oldVal is Map && newVal is Map) {
        if (oldVal.length != newVal.length) return false;
        for (final key in oldVal.keys) {
          if (oldVal[key] != newVal[key]) return false;
        }
        return true;
      }
      return oldVal == newVal;
    }

    // Helper to serialize value for storage
    dynamic serializeValue(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toIso8601String();
      if (value is List) return value;
      if (value is Map) return value;
      return value;
    }

    // Compare each field
    if (!valuesEqual(oldSpot.name, newSpot.name)) {
      changes['name'] = {
        'from': oldSpot.name,
        'to': newSpot.name,
      };
    }

    if (!valuesEqual(oldSpot.description, newSpot.description)) {
      changes['description'] = {
        'from': oldSpot.description,
        'to': newSpot.description,
      };
    }

    if (oldSpot.latitude != newSpot.latitude || oldSpot.longitude != newSpot.longitude) {
      changes['location'] = {
        'from': {'latitude': oldSpot.latitude, 'longitude': oldSpot.longitude},
        'to': {'latitude': newSpot.latitude, 'longitude': newSpot.longitude},
      };
    }

    if (!valuesEqual(oldSpot.address, newSpot.address)) {
      changes['address'] = {
        'from': oldSpot.address,
        'to': newSpot.address,
      };
    }

    if (!valuesEqual(oldSpot.city, newSpot.city)) {
      changes['city'] = {
        'from': oldSpot.city,
        'to': newSpot.city,
      };
    }

    if (!valuesEqual(oldSpot.countryCode, newSpot.countryCode)) {
      changes['countryCode'] = {
        'from': oldSpot.countryCode,
        'to': newSpot.countryCode,
      };
    }

    if (!valuesEqual(oldSpot.imageUrls, newSpot.imageUrls)) {
      changes['imageUrls'] = {
        'from': serializeValue(oldSpot.imageUrls),
        'to': serializeValue(newSpot.imageUrls),
      };
    }

    if (!valuesEqual(oldSpot.youtubeVideoIds, newSpot.youtubeVideoIds)) {
      changes['youtubeVideoIds'] = {
        'from': serializeValue(oldSpot.youtubeVideoIds),
        'to': serializeValue(newSpot.youtubeVideoIds),
      };
    }

    if (!valuesEqual(oldSpot.spotAccess, newSpot.spotAccess)) {
      changes['spotAccess'] = {
        'from': oldSpot.spotAccess,
        'to': newSpot.spotAccess,
      };
    }

    if (!valuesEqual(oldSpot.spotFeatures, newSpot.spotFeatures)) {
      changes['spotFeatures'] = {
        'from': serializeValue(oldSpot.spotFeatures),
        'to': serializeValue(newSpot.spotFeatures),
      };
    }

    if (!valuesEqual(oldSpot.spotFacilities, newSpot.spotFacilities)) {
      changes['spotFacilities'] = {
        'from': serializeValue(oldSpot.spotFacilities),
        'to': serializeValue(newSpot.spotFacilities),
      };
    }

    if (!valuesEqual(oldSpot.goodFor, newSpot.goodFor)) {
      changes['goodFor'] = {
        'from': serializeValue(oldSpot.goodFor),
        'to': serializeValue(newSpot.goodFor),
      };
    }

    if (!valuesEqual(oldSpot.duplicateOf, newSpot.duplicateOf)) {
      changes['duplicateOf'] = {
        'from': oldSpot.duplicateOf,
        'to': newSpot.duplicateOf,
      };
    }

    return changes;
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

  // Get top ranked spots within bounds using backend Wilson logic
  Future<Map<String, dynamic>> getTopRankedSpotsInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int limit = 100,
    String? spotSource, // null = all sources, empty string = native only, string = specific source
    bool hasImages = false, // true = only spots with images, false = all spots
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('getTopSpotsInBounds');
      final Map<String, dynamic> requestData = {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
        'limit': limit,
      };
      // Only include spotSource if it's not null (null means all sources)
      if (spotSource != null) {
        requestData['spotSource'] = spotSource;
      }
      // Only include hasImages if it's true (false means all spots)
      if (hasImages) {
        requestData['hasImages'] = true;
      }
      final result = await callable.call(requestData);

      final responseData = result.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        throw Exception(responseData != null && responseData['error'] is String ? responseData['error'] : 'Unknown error');
      }

      final List<dynamic> items = (responseData['spots'] as List<dynamic>? ?? <dynamic>[]);
      final spots = items
          .whereType<Map<String, dynamic>>()
          .map((m) => Spot.fromMap(m))
          .toList();

      return {
        'spots': spots,
        'totalCount': (responseData['totalCount'] as num?)?.toInt() ?? spots.length,
        'shownCount': (responseData['shownCount'] as num?)?.toInt() ?? spots.length,
        'averageWilson': (responseData['averageWilson'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting top ranked spots in bounds: $e');
      return {'spots': <Spot>[], 'totalCount': 0, 'shownCount': 0, 'averageWilson': 0.0};
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

  Future<Map<String, int>> backfillMissingDuplicateOf({int batchSize = 400}) async {
    try {
      _isLoading = true;
      notifyListeners();

      int totalMatched = 0;
      int updatedCount = 0;
      int alreadyHadField = 0;

      // Query all spots in batches since we can't query for missing fields directly
      Query query = _firestore.collection('spots').orderBy(FieldPath.documentId).limit(1000);
      DocumentSnapshot? lastDoc;
      bool hasMore = true;

      WriteBatch? writeBatch;
      int writeBatchCount = 0;

      while (hasMore) {
        Query currentQuery = lastDoc == null 
            ? query 
            : query.startAfterDocument(lastDoc);

        final querySnapshot = await currentQuery.get();

        if (querySnapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          
          // Check if the document is missing the duplicateOf field
          if (data == null || !data.containsKey('duplicateOf')) {
            totalMatched++;
            
            writeBatch ??= _firestore.batch();
            writeBatch.update(doc.reference, {'duplicateOf': null});
            writeBatchCount++;
            updatedCount++;

            if (writeBatchCount >= batchSize) {
              await writeBatch.commit();
              writeBatch = null;
              writeBatchCount = 0;
            }
          } else {
            // Field exists, count it as already having the field
            alreadyHadField++;
          }
        }

        // Check if we need to continue paginating
        if (querySnapshot.docs.length < 1000) {
          hasMore = false;
        } else {
          lastDoc = querySnapshot.docs.last;
        }
      }

      // Commit any remaining writes
      if (writeBatch != null && writeBatchCount > 0) {
        await writeBatch.commit();
      }

      return {
        'matched': totalMatched,
        'updated': updatedCount,
        'skipped': alreadyHadField,
      };
    } catch (e) {
      _error = 'Failed to backfill duplicateOf: $e';
      debugPrint('Error backfilling duplicateOf: $e');
      rethrow;
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
  Future<bool> markSpotAsDuplicate(
    String spotId,
    String originalSpotId, {
    bool transferPhotos = false,
    bool transferYoutubeLinks = false,
    bool overwriteName = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSpotAttributes = false,
    String? userId,
    String? userName,
  }) async {
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

      // Get the duplicate spot to transfer its data
      final duplicateSpot = await getSpotById(spotId);
      if (duplicateSpot == null) {
        _error = 'Duplicate spot not found';
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

      // Prepare updates for the original spot
      Map<String, dynamic> originalSpotUpdates = {};
      bool needsOriginalUpdate = false;

      // Merge photos if requested
      if (transferPhotos && duplicateSpot.imageUrls != null && duplicateSpot.imageUrls!.isNotEmpty) {
        final existingPhotos = List<String>.from(originalSpot.imageUrls ?? []);
        final newPhotos = duplicateSpot.imageUrls!
            .where((url) => !existingPhotos.contains(url))
            .toList();
        
        if (newPhotos.isNotEmpty) {
          originalSpotUpdates['imageUrls'] = [...existingPhotos, ...newPhotos];
          needsOriginalUpdate = true;
        }
      }

      // Merge YouTube links if requested
      if (transferYoutubeLinks && duplicateSpot.youtubeVideoIds != null && duplicateSpot.youtubeVideoIds!.isNotEmpty) {
        final existingYoutubeLinks = List<String>.from(originalSpot.youtubeVideoIds ?? []);
        final newYoutubeLinks = duplicateSpot.youtubeVideoIds!
            .where((id) => !existingYoutubeLinks.contains(id))
            .toList();
        
        if (newYoutubeLinks.isNotEmpty) {
          originalSpotUpdates['youtubeVideoIds'] = [...existingYoutubeLinks, ...newYoutubeLinks];
          needsOriginalUpdate = true;
        }
      }

      // Overwrite name if requested and duplicate has a name
      if (overwriteName && duplicateSpot.name.isNotEmpty) {
        originalSpotUpdates['name'] = duplicateSpot.name;
        needsOriginalUpdate = true;
      }

      // Overwrite description if requested and duplicate has a description
      if (overwriteDescription && duplicateSpot.description.isNotEmpty) {
        originalSpotUpdates['description'] = duplicateSpot.description;
        needsOriginalUpdate = true;
      }

      // Overwrite location if requested and duplicate has location data
      if (overwriteLocation) {
        bool hasLocationData = false;
        if (duplicateSpot.latitude != 0.0 && duplicateSpot.longitude != 0.0) {
          originalSpotUpdates['latitude'] = duplicateSpot.latitude;
          originalSpotUpdates['longitude'] = duplicateSpot.longitude;
          hasLocationData = true;
        }
        if (duplicateSpot.address != null && duplicateSpot.address!.isNotEmpty) {
          originalSpotUpdates['address'] = duplicateSpot.address;
          hasLocationData = true;
        }
        if (duplicateSpot.city != null && duplicateSpot.city!.isNotEmpty) {
          originalSpotUpdates['city'] = duplicateSpot.city;
          hasLocationData = true;
        }
        if (duplicateSpot.countryCode != null && duplicateSpot.countryCode!.isNotEmpty) {
          originalSpotUpdates['countryCode'] = duplicateSpot.countryCode;
          hasLocationData = true;
        }
        if (hasLocationData) {
          needsOriginalUpdate = true;
        }
      }

      // Overwrite spot attributes if requested and duplicate has attributes
      if (overwriteSpotAttributes) {
        bool hasAttributes = false;
        if (duplicateSpot.spotAccess != null && duplicateSpot.spotAccess!.isNotEmpty) {
          originalSpotUpdates['spotAccess'] = duplicateSpot.spotAccess;
          hasAttributes = true;
        }
        if (duplicateSpot.spotFeatures != null && duplicateSpot.spotFeatures!.isNotEmpty) {
          originalSpotUpdates['spotFeatures'] = duplicateSpot.spotFeatures;
          hasAttributes = true;
        }
        if (duplicateSpot.spotFacilities != null && duplicateSpot.spotFacilities!.isNotEmpty) {
          originalSpotUpdates['spotFacilities'] = duplicateSpot.spotFacilities;
          hasAttributes = true;
        }
        if (duplicateSpot.goodFor != null && duplicateSpot.goodFor!.isNotEmpty) {
          originalSpotUpdates['goodFor'] = duplicateSpot.goodFor;
          hasAttributes = true;
        }
        if (hasAttributes) {
          needsOriginalUpdate = true;
        }
      }

      // Update the original spot if needed
      if (needsOriginalUpdate) {
        originalSpotUpdates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('spots').doc(originalSpotId).update(originalSpotUpdates);
      }

      // Update the spot to mark it as duplicate
      await _firestore.collection('spots').doc(spotId).update({
        'duplicateOf': originalSpotId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log audit trail if user info is provided (moderator action)
      if (userId != null && userName != null) {
        await _auditLogService.logSpotMarkedAsDuplicate(
          spotId: spotId,
          originalSpotId: originalSpotId,
          userId: userId,
          userName: userName,
          transferPhotos: transferPhotos,
          transferYoutubeLinks: transferYoutubeLinks,
          overwriteName: overwriteName,
          overwriteDescription: overwriteDescription,
          overwriteLocation: overwriteLocation,
          overwriteSpotAttributes: overwriteSpotAttributes,
        );
      }

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

  // Import URBN spots from JSON (admin only)
  Future<Map<String, dynamic>> importUrbnSpots(List<Map<String, dynamic>> spots) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'importUrbnSpots',
        options: HttpsCallableOptions(
          timeout: const Duration(hours: 1),
        ),
      );
      final result = await callable.call({'spots': spots});
      final data = result.data as Map<String, dynamic>;
      
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _error = 'Failed to import URBN spots: $e';
      debugPrint('Error importing URBN spots: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Hide or unhide a spot (moderator only)
  Future<bool> setSpotHidden(
    String spotId,
    bool hidden, {
    String? userId,
    String? userName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get the current spot to check if it exists
      final spot = await getSpotById(spotId);
      if (spot == null) {
        _error = 'Spot not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update the hidden field
      await _firestore.collection('spots').doc(spotId).update({
        'hidden': hidden,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log audit trail if user info is provided (moderator action)
      if (userId != null && userName != null) {
        await _auditLogService.logSpotHidden(
          spotId: spotId,
          hidden: hidden,
          userId: userId,
          userName: userName,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to ${hidden ? 'hide' : 'unhide'} spot: $e';
      debugPrint('Error ${hidden ? 'hiding' : 'unhiding'} spot: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
