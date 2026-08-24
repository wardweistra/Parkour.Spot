import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import '../models/spot.dart';
import '../models/rating.dart';
import '../utils/duplicate_spot_resolution_utils.dart';
import '../utils/image_preparation.dart';
import '../utils/image_url_utils.dart';
import '../utils/replay_latest_stream.dart';
import '../utils/spot_duplicate_merge.dart';
import '../utils/spot_duplicate_review.dart';
import '../utils/ui_yield.dart';
import 'audit_log_service.dart';

class SpotService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuditLogService _auditLogService = AuditLogService();

  bool _isLoading = false;
  String? _error;

  Stream<int>? _duplicatePendingChangesCountStream;
  int _duplicatePendingChangesCount = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Count of duplicates with unreviewed field changes.
  int get duplicatePendingChangesCount => _duplicatePendingChangesCount;

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

  /// Search spots by title across all spots in the database.
  Future<List<Spot>> searchSpotsByTitle({
    required String query,
    int limit = 8,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('searchSpotsByTitle');
      final result = await callable.call({
        'query': trimmedQuery,
        'limit': limit,
      });

      final data = result.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        return [];
      }

      final items = (data['spots'] as List<dynamic>? ?? <dynamic>[]);
      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => Spot.fromMap(item))
          .where((spot) => spot.id != null)
          .toList();
    } catch (e) {
      debugPrint('Error searching spots by title: $e');
      return [];
    }
  }

  /// Warms the spot-title search Cloud Function without querying Firestore.
  Future<void> warmupSearchSpotsByTitle() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('searchSpotsByTitle');
      await callable.call({'warmup': true});
    } catch (e) {
      debugPrint('Error warming searchSpotsByTitle: $e');
    }
  }

  // Create a native spot from an existing spot (copies name, description, location, photos, youtube link)
  Future<String?> createNativeSpotFromExisting(
    Spot sourceSpot,
    String createdBy,
    String createdByName,
  ) async {
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
        hidden: false, // New spot, not hidden
        createdFromCreateNative: true,
        // spotSource is null (native spot)
      );

      final docRef = await _firestore
          .collection('spots')
          .add(nativeSpot.toFirestore());

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
  Future<String?> createSpot(
    Spot spot, {
    File? imageFile,
    Uint8List? imageBytes,
    List<File>? imageFiles,
    List<Uint8List>? imageBytesList,
    List<PreparedImage>? preparedPhotos,
    void Function(int current, int total)? onUploadProgress,
  }) async {
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
      } else if (preparedPhotos != null && preparedPhotos.isNotEmpty) {
        imageUrls = await _uploadPreparedImages(
          preparedPhotos,
          pathPrefix: 'spots/',
          fileNameStem: 'web_image',
          onProgress: onUploadProgress,
        );
      } else if (imageBytesList != null && imageBytesList.isNotEmpty) {
        imageUrls = await _uploadImagesBytes(imageBytesList);
      }

      final spotWithImages = spot.copyWith(
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ranking: spot.ranking ?? Random().nextDouble(),
        duplicateOf: null, // New spot, not a duplicate
        hidden: spot
            .hidden, // Preserve hidden field (defaults to false for new spots)
      );

      final docRef = await _firestore
          .collection('spots')
          .add(spotWithImages.toFirestore());

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
    Spot spot, {
    List<File>? newImageFiles,
    List<Uint8List>? newImageBytesList,
    List<String>? imagesToDelete,
    String? userId,
    String? userName,
    String? reportId,
    String? notes,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get the old spot data for audit logging
      Spot? oldSpot;
      if (userId != null && userName != null) {
        oldSpot = await getSpotById(spot.id!);
      }

      List<String>? imageUrls = List.from(spot.imageUrls ?? []);

      // Remove images from spot (but don't delete from storage - cleanup will handle that)
      if (imagesToDelete != null && imagesToDelete.isNotEmpty) {
        for (final imageUrl in imagesToDelete) {
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
        hidden: spot.hidden, // Preserve existing hidden field
      );

      final payload = updatedSpot.toFirestore(isUpdate: true);
      if ((oldSpot?.duplicateOf ?? '').trim().isNotEmpty &&
          (updatedSpot.duplicateOf ?? '').trim().isEmpty) {
        payload.addAll(buildSpotDuplicateReviewClearUpdates());
      }

      await _firestore.collection('spots').doc(spot.id).update(payload);

      // Log audit trail if user info is provided (moderator edit)
      if (userId != null && userName != null && oldSpot != null) {
        final changes = _computeSpotChanges(oldSpot, updatedSpot);
        if (changes.isNotEmpty) {
          await _auditLogService.logSpotEdit(
            spotId: spot.id!,
            userId: userId,
            userName: userName,
            changes: changes,
            reportId: reportId,
            notes: notes,
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

  /// Applies accepted edit suggestions from a spot report.
  /// [updates] contains the field values to apply (only accepted fields).
  /// Adds reporter to contributors when any edit is applied.
  Future<bool> applyEditSuggestions({
    required Spot spot,
    required Map<String, dynamic> updates,
    required String? reporterUserId,
    required String? reporterUserName,
    required String reportId,
    String? moderatorUserId,
    String? moderatorUserName,
    String? notes,
  }) async {
    if (spot.id == null || updates.isEmpty) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final oldSpot = await getSpotById(spot.id!);
      if (oldSpot == null) {
        _error = 'Spot not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      Spot updatedSpot = oldSpot;

      if (updates.containsKey('name')) {
        updatedSpot = updatedSpot.copyWith(name: updates['name'] as String?);
      }
      if (updates.containsKey('description')) {
        updatedSpot = updatedSpot.copyWith(
          description: updates['description'] as String?,
        );
      }
      if (updates.containsKey('latitude') && updates.containsKey('longitude')) {
        updatedSpot = updatedSpot.copyWith(
          latitude: (updates['latitude'] as num).toDouble(),
          longitude: (updates['longitude'] as num).toDouble(),
          address: updates['address'] as String?,
          city: updates['city'] as String?,
          countryCode: updates['countryCode'] as String?,
        );
      }
      if (updates.containsKey('goodFor')) {
        updatedSpot = updatedSpot.copyWith(
          goodFor: updates['goodFor'] is List
              ? List<String>.from(updates['goodFor'] as List)
              : null,
        );
      }
      if (updates.containsKey('spotFeatures')) {
        updatedSpot = updatedSpot.copyWith(
          spotFeatures: updates['spotFeatures'] is List
              ? List<String>.from(updates['spotFeatures'] as List)
              : null,
        );
      }
      if (updates.containsKey('spotAccess')) {
        updatedSpot = updatedSpot.copyWith(
          spotAccess: updates['spotAccess'] as String?,
        );
      }
      if (updates.containsKey('spotFacilities')) {
        updatedSpot = updatedSpot.copyWith(
          spotFacilities: updates['spotFacilities'] is Map
              ? Map<String, String>.from(updates['spotFacilities'] as Map)
              : null,
        );
      }

      List<Map<String, String>> contributors = List.from(
        updatedSpot.contributors ?? [],
      );
      final resolvedContributor = resolveSuggestionContributor(
        reporterUserId: reporterUserId,
        reporterUserName: reporterUserName,
        approverUserId: moderatorUserId,
        approverUserName: moderatorUserName,
      );
      if (resolvedContributor != null) {
        final contributorUserId = resolvedContributor['userId']!;
        final exists = contributors.any(
          (c) => c['userId'] == contributorUserId,
        );
        if (!exists) {
          contributors.add(resolvedContributor);
        }
      }

      updatedSpot = updatedSpot.copyWith(
        contributors: contributors,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('spots')
          .doc(spot.id)
          .update(updatedSpot.toFirestore(isUpdate: true));

      final changes = _computeSpotChanges(oldSpot, updatedSpot);
      if (changes.isNotEmpty) {
        await _auditLogService.logSpotEdit(
          spotId: spot.id!,
          userId: moderatorUserId ?? reporterUserId,
          userName: moderatorUserName ?? reporterUserName,
          changes: changes,
          reportId: reportId,
          notes: notes,
          metadata: {
            'suggestedBy': {
              'userId': reporterUserId,
              'userName': reporterUserName,
            },
          },
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error applying edit suggestions: $e');
      _error = 'Failed to apply edit suggestions: $e';
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
      changes['name'] = {'from': oldSpot.name, 'to': newSpot.name};
    }

    if (!valuesEqual(oldSpot.description, newSpot.description)) {
      changes['description'] = {
        'from': oldSpot.description,
        'to': newSpot.description,
      };
    }

    if (oldSpot.latitude != newSpot.latitude ||
        oldSpot.longitude != newSpot.longitude) {
      changes['location'] = {
        'from': {'latitude': oldSpot.latitude, 'longitude': oldSpot.longitude},
        'to': {'latitude': newSpot.latitude, 'longitude': newSpot.longitude},
      };
    }

    if (!valuesEqual(oldSpot.address, newSpot.address)) {
      changes['address'] = {'from': oldSpot.address, 'to': newSpot.address};
    }

    if (!valuesEqual(oldSpot.city, newSpot.city)) {
      changes['city'] = {'from': oldSpot.city, 'to': newSpot.city};
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
      final bytes = await imageFile.readAsBytes();
      final prepared = await prepareImageForUpload(bytes);
      final ext = _extensionForContentType(prepared.contentType);
      final fileName =
          'spots/${DateTime.now().millisecondsSinceEpoch}_web_image$ext';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        prepared.bytes,
        SettableMetadata(contentType: prepared.contentType),
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
      final prepared = await prepareImageForUpload(imageBytes);
      final ext = _extensionForContentType(prepared.contentType);
      final fileName =
          'spots/${DateTime.now().millisecondsSinceEpoch}_web_image$ext';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        prepared.bytes,
        SettableMetadata(contentType: prepared.contentType),
      );
      final snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image bytes: $e');
      rethrow;
    }
  }

  String _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
  }

  Future<String> _uploadPreparedImage(
    PreparedImage prepared,
    String fileName,
  ) async {
    await yieldToUi();
    final ref = _storage.ref().child(fileName);
    final snapshot = await ref.putData(
      prepared.bytes,
      SettableMetadata(contentType: prepared.contentType),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<List<String>> _uploadPreparedImages(
    List<PreparedImage> preparedPhotos, {
    required String pathPrefix,
    required String fileNameStem,
    void Function(int current, int total)? onProgress,
  }) async {
    final photoUrls = <String>[];
    final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
    final total = preparedPhotos.length;
    for (var i = 0; i < preparedPhotos.length; i++) {
      onProgress?.call(i + 1, total);
      final prepared = preparedPhotos[i];
      final ext = _extensionForContentType(prepared.contentType);
      final fileName = '$pathPrefix${baseTimestamp}_${fileNameStem}_$i$ext';
      photoUrls.add(await _uploadPreparedImage(prepared, fileName));
    }
    return photoUrls;
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
  Future<List<String>> _uploadImagesBytes(
    List<Uint8List> imageBytesList,
  ) async {
    final List<String> imageUrls = [];
    for (final imageBytes in imageBytesList) {
      final imageUrl = await _uploadImageBytes(imageBytes);
      imageUrls.add(imageUrl);
    }
    return imageUrls;
  }

  // Upload photos to /suggestions/ path (temporary storage, does NOT trigger resize extension)
  Future<List<String>> uploadSuggestedPhotos({
    List<File>? photoFiles,
    List<Uint8List>? photoBytesList,
    List<PreparedImage>? preparedPhotos,
  }) async {
    try {
      if (preparedPhotos != null && preparedPhotos.isNotEmpty) {
        return _uploadPreparedImages(
          preparedPhotos,
          pathPrefix: 'suggestions/',
          fileNameStem: 'web_image',
        );
      }

      final List<String> photoUrls = [];

      if (photoFiles != null && photoFiles.isNotEmpty) {
        for (int i = 0; i < photoFiles.length; i++) {
          final photoFile = photoFiles[i];
          final bytes = await photoFile.readAsBytes();
          final prepared = await prepareImageForUpload(bytes);
          final ext = _extensionForContentType(prepared.contentType);
          final fileName =
              'suggestions/${DateTime.now().millisecondsSinceEpoch}_image_$i$ext';
          photoUrls.add(await _uploadPreparedImage(prepared, fileName));
        }
      } else if (photoBytesList != null && photoBytesList.isNotEmpty) {
        for (int i = 0; i < photoBytesList.length; i++) {
          final photoBytes = photoBytesList[i];
          final prepared = await prepareImageForUpload(photoBytes);
          final ext = _extensionForContentType(prepared.contentType);
          final fileName =
              'suggestions/${DateTime.now().millisecondsSinceEpoch}_web_image_$i$ext';
          photoUrls.add(await _uploadPreparedImage(prepared, fileName));
        }
      }

      return photoUrls;
    } catch (e) {
      debugPrint('Error uploading suggested photos: $e');
      rethrow;
    }
  }

  // Move photos from /suggestions/ to /spots/ and add to spot
  // Returns the new photo URLs from /spots/ path, or null if failed
  Future<List<String>?> addPhotosToSpot({
    required String spotId,
    required List<String> photoUrls, // URLs from /suggestions/ path
    required String? userId,
    required String? userName,
    String? reportId,
    String? notes,
    String?
    targetSpotId, // Optional: if spot is duplicate, add to original spot instead
    String?
    approvedByUserId, // Optional: userId of the approver (for audit log)
    String?
    approvedByUserName, // Optional: userName of the approver (for audit log)
    void Function(int current, int total, {String phase})? onProgress,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Determine target spot (use targetSpotId if provided, otherwise use spotId)
      final finalSpotId = targetSpotId ?? spotId;

      // Get the target spot
      final targetSpot = await getSpotById(finalSpotId);
      if (targetSpot == null) {
        _error = 'Target spot not found';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Move photos from /suggestions/ to /spots/
      final List<String> finalPhotoUrls = [];
      final total = photoUrls.length;
      var current = 0;
      for (final photoUrl in photoUrls) {
        try {
          current++;
          onProgress?.call(current, total, phase: 'Downloading');
          await yieldToUi();

          // Extract the file path from the URL
          final uri = Uri.parse(photoUrl);
          String? filePath;

          // Handle Firebase Storage URL formats
          if (uri.pathSegments.contains('o')) {
            // Format: /v0/b/bucket/o/suggestions%2Ffilename.jpg
            final encodedPath =
                uri.pathSegments[uri.pathSegments.indexOf('o') + 1];
            filePath = Uri.decodeComponent(encodedPath);
          } else if (uri.host.contains('storage.googleapis.com')) {
            // Format: https://storage.googleapis.com/bucket/suggestions/filename.jpg
            final pathIndex = uri.pathSegments.indexOf('suggestions');
            if (pathIndex != -1 && pathIndex + 1 < uri.pathSegments.length) {
              filePath = uri.pathSegments.sublist(pathIndex).join('/');
            }
          }

          if (filePath == null || !filePath.startsWith('suggestions/')) {
            debugPrint('Invalid photo URL format: $photoUrl');
            continue;
          }

          // Create new path in /spots/ (use .jpg since we resize to JPEG)
          final suggestedPath = filePath.replaceFirst('suggestions/', 'spots/');
          final baseName = suggestedPath.split('.').first;
          final newPath = '$baseName.jpg';

          final sourceRef = _storage.ref().child(filePath);
          final destRef = _storage.ref().child(newPath);

          // Fetch via HTTP (bypasses getData's 10MB limit), then resize off the
          // main thread to avoid freezing the UI with large images.
          final response = await http.get(Uri.parse(photoUrl));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            debugPrint('Failed to fetch photo: ${response.statusCode}');
            continue;
          }
          final rawBytes = response.bodyBytes;

          onProgress?.call(current, total, phase: 'Processing');
          await yieldToUi();
          PreparedImage prepared;
          try {
            prepared = await prepareImageForSpotPromotion(
              rawBytes,
              maxDimension: 2048,
              jpegQuality: 85,
            );
          } on ImagePreparationException catch (e) {
            debugPrint('Failed to prepare photo $photoUrl: $e');
            continue;
          }
          await yieldToUi();

          onProgress?.call(current, total, phase: 'Uploading');
          await yieldToUi();
          await destRef.putData(
            prepared.bytes,
            SettableMetadata(contentType: prepared.contentType),
          );
          final newUrl = await destRef.getDownloadURL();
          finalPhotoUrls.add(newUrl);
          await sourceRef.delete();
        } catch (e) {
          debugPrint('Error moving photo $photoUrl: $e');
          // Continue with other photos even if one fails
        }
      }

      if (finalPhotoUrls.isEmpty) {
        _error = 'Failed to move any photos';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Get current image URLs and add new ones (avoid duplicates)
      List<String> updatedImageUrls = List.from(targetSpot.imageUrls ?? []);
      for (final photoUrl in finalPhotoUrls) {
        if (!updatedImageUrls.contains(photoUrl)) {
          updatedImageUrls.add(photoUrl);
        }
      }

      // Update contributors list (credit suggester first, fallback to approver)
      List<Map<String, String>> updatedContributors = List.from(
        targetSpot.contributors ?? [],
      );
      final resolvedContributor = resolveSuggestionContributor(
        reporterUserId: userId,
        reporterUserName: userName,
        approverUserId: approvedByUserId,
        approverUserName: approvedByUserName,
      );
      if (resolvedContributor != null) {
        final contributorUserId = resolvedContributor['userId']!;
        final contributorExists = updatedContributors.any(
          (c) => c['userId'] == contributorUserId,
        );
        if (!contributorExists) {
          updatedContributors.add(resolvedContributor);
        }
      }

      // Update the spot
      final updatedSpot = targetSpot.copyWith(
        imageUrls: updatedImageUrls,
        contributors: updatedContributors,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('spots')
          .doc(finalSpotId)
          .update(updatedSpot.toFirestore(isUpdate: true));

      // Log audit trail (use approver info if provided, otherwise use contributor info)
      final auditUserId = approvedByUserId ?? userId;
      final auditUserName = approvedByUserName ?? userName;
      if (auditUserId != null && auditUserName != null) {
        await _auditLogService.logPhotoAdded(
          spotId: finalSpotId,
          photoUrls: finalPhotoUrls,
          userId: auditUserId,
          userName: auditUserName,
          reportId: reportId,
          originalPhotoUrls:
              photoUrls, // Keep track of original URLs from suggestions
          notes: notes,
        );
      }

      _isLoading = false;
      notifyListeners();
      return finalPhotoUrls; // Return the new URLs from /spots/
    } catch (e) {
      debugPrint('Error adding photos to spot: $e');
      _error = 'Failed to add photos to spot: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  @visibleForTesting
  static Map<String, String>? resolveSuggestionContributor({
    String? reporterUserId,
    String? reporterUserName,
    String? approverUserId,
    String? approverUserName,
  }) {
    final normalizedReporterUserId = reporterUserId?.trim();
    final normalizedReporterUserName = reporterUserName?.trim();
    final normalizedApproverUserId = approverUserId?.trim();
    final normalizedApproverUserName = approverUserName?.trim();

    final hasReporter =
        normalizedReporterUserId != null && normalizedReporterUserId.isNotEmpty;
    final selectedUserId = hasReporter
        ? normalizedReporterUserId
        : normalizedApproverUserId;

    if (selectedUserId == null || selectedUserId.isEmpty) {
      return null;
    }

    final selectedUserName = hasReporter
        ? normalizedReporterUserName
        : normalizedApproverUserName;

    return <String, String>{
      'userId': selectedUserId,
      'userName': (selectedUserName != null && selectedUserName.isNotEmpty)
          ? selectedUserName
          : selectedUserId,
    };
  }

  // Move photos from /suggestions/ to /rejected/ path (used when rejecting photo suggestions)
  Future<List<String>> movePhotosToRejected(
    List<String> photoUrls, {
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      final List<String> rejectedUrls = [];
      final total = photoUrls.length;

      for (var i = 0; i < photoUrls.length; i++) {
        final photoUrl = photoUrls[i];
        try {
          onProgress?.call(i + 1, total);
          await yieldToUi();

          // Extract the file path from the URL
          final uri = Uri.parse(photoUrl);
          String? filePath;

          // Handle Firebase Storage URL formats
          if (uri.pathSegments.contains('o')) {
            final encodedPath =
                uri.pathSegments[uri.pathSegments.indexOf('o') + 1];
            filePath = Uri.decodeComponent(encodedPath);
          } else if (uri.host.contains('storage.googleapis.com')) {
            final pathIndex = uri.pathSegments.indexOf('suggestions');
            if (pathIndex != -1 && pathIndex + 1 < uri.pathSegments.length) {
              filePath = uri.pathSegments.sublist(pathIndex).join('/');
            }
          }

          if (filePath != null && filePath.startsWith('suggestions/')) {
            // Create new path in /rejected/
            final newPath = filePath.replaceFirst('suggestions/', 'rejected/');

            // Get references
            final sourceRef = _storage.ref().child(filePath);
            final destRef = _storage.ref().child(newPath);

            // Copy the file
            final data = await sourceRef.getData();
            if (data != null) {
              // Get content type from metadata
              final metadata = await sourceRef.getMetadata();
              final contentType = metadata.contentType ?? 'image/jpeg';

              // Upload to rejected location
              await destRef.putData(
                data,
                SettableMetadata(contentType: contentType),
              );

              // Get the new URL
              final newUrl = await destRef.getDownloadURL();
              rejectedUrls.add(newUrl);

              // Delete the original from /suggestions/
              await sourceRef.delete();
            }
          }
        } catch (e) {
          debugPrint('Error moving suggested photo to rejected $photoUrl: $e');
          // Continue with other photos even if one fails
        }
      }

      return rejectedUrls;
    } catch (e) {
      debugPrint('Error moving suggested photos to rejected: $e');
      return [];
    }
  }

  // Move photos from /rejected/ back to /suggestions/ path (used when undoing rejection)
  Future<List<String>> movePhotosFromRejectedToSuggestions(
    List<String> rejectedPhotoUrls,
  ) async {
    try {
      final List<String> suggestionUrls = [];

      for (final photoUrl in rejectedPhotoUrls) {
        try {
          // Extract the file path from the URL
          final uri = Uri.parse(photoUrl);
          String? filePath;

          // Handle Firebase Storage URL formats
          if (uri.pathSegments.contains('o')) {
            final encodedPath =
                uri.pathSegments[uri.pathSegments.indexOf('o') + 1];
            filePath = Uri.decodeComponent(encodedPath);
          } else if (uri.host.contains('storage.googleapis.com')) {
            final pathIndex = uri.pathSegments.indexOf('rejected');
            if (pathIndex != -1 && pathIndex + 1 < uri.pathSegments.length) {
              filePath = uri.pathSegments.sublist(pathIndex).join('/');
            }
          }

          if (filePath != null && filePath.startsWith('rejected/')) {
            // Create new path in /suggestions/
            final newPath = filePath.replaceFirst('rejected/', 'suggestions/');

            // Get references
            final sourceRef = _storage.ref().child(filePath);
            final destRef = _storage.ref().child(newPath);

            // Copy the file
            final data = await sourceRef.getData();
            if (data != null) {
              // Get content type from metadata
              final metadata = await sourceRef.getMetadata();
              final contentType = metadata.contentType ?? 'image/jpeg';

              // Upload to suggestions location
              await destRef.putData(
                data,
                SettableMetadata(contentType: contentType),
              );

              // Get the new URL
              final newUrl = await destRef.getDownloadURL();
              suggestionUrls.add(newUrl);

              // Delete the original from /rejected/
              await sourceRef.delete();
            }
          }
        } catch (e) {
          debugPrint(
            'Error moving rejected photo back to suggestions $photoUrl: $e',
          );
          // Continue with other photos even if one fails
        }
      }

      return suggestionUrls;
    } catch (e) {
      debugPrint('Error moving rejected photos back to suggestions: $e');
      return [];
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
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
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
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Error recomputing spot rankings: $e');
      rethrow;
    }
  }

  /// Admin: Trigger sitemap generation (countries, unlocated spots, lists, users).
  Future<void> generateSitemaps() async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable(
      'generateSitemaps',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
    );
    final result = await callable.call();
    final data = result.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['error'] ?? 'Sitemap generation failed');
    }
  }

  // Get top ranked spots within bounds using backend Wilson logic
  Future<Map<String, dynamic>> getTopRankedSpotsInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int limit = 100,
    bool hasImages = false, // true = only spots with images
    String? filterArea, // "amenities" | "source" | null (null = source)
    String?
    spotSource, // when source: null = all, "" = native, string = specific source
    List<String>?
    folders, // when source: list of folder names (null = all folders)
    List<String>?
    spotAccess, // when amenities: ["public", "restricted", "paid"] for OR query, empty = any
    bool? spotFacilitiesCovered, // when amenities: true = "yes"
    bool? spotFacilitiesLighting, // when amenities: true = "yes"
    bool? spotFacilitiesWaterTap, // when amenities: true = "yes"
    bool? spotFacilitiesToilet, // when amenities: true = "yes"
    bool? spotFacilitiesParking, // when amenities: true = "yes"
    List<String>? goodFor, // when amenities: array-contains-any
    List<String>? spotFeatures, // when amenities: array-contains-any
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
      if (hasImages) {
        requestData['hasImages'] = true;
      }
      if (filterArea != null) {
        requestData['filterArea'] = filterArea;
      }
      if (filterArea == 'amenities') {
        if (spotAccess != null && spotAccess.isNotEmpty) {
          requestData['spotAccess'] = spotAccess.length == 1
              ? spotAccess.first
              : spotAccess;
        }
        if (spotFacilitiesCovered == true) {
          requestData['spotFacilitiesCovered'] = 'yes';
        }
        if (spotFacilitiesLighting == true) {
          requestData['spotFacilitiesLighting'] = 'yes';
        }
        if (spotFacilitiesWaterTap == true) {
          requestData['spotFacilitiesWaterTap'] = 'yes';
        }
        if (spotFacilitiesToilet == true) {
          requestData['spotFacilitiesToilet'] = 'yes';
        }
        if (spotFacilitiesParking == true) {
          requestData['spotFacilitiesParking'] = 'yes';
        }
        if (goodFor != null && goodFor.isNotEmpty) {
          requestData['goodFor'] = goodFor.take(10).toList();
        }
        if (spotFeatures != null && spotFeatures.isNotEmpty) {
          requestData['spotFeatures'] = spotFeatures.take(10).toList();
        }
      } else {
        if (spotSource != null) {
          requestData['spotSource'] = spotSource;
        }
        if (folders != null && folders.isNotEmpty && spotSource != null) {
          requestData['folders'] = folders;
        }
      }
      final result = await callable.call(requestData);

      final responseData = result.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        throw Exception(
          responseData != null && responseData['error'] is String
              ? responseData['error']
              : 'Unknown error',
        );
      }

      final List<dynamic> items =
          (responseData['spots'] as List<dynamic>? ?? <dynamic>[]);
      final spots = items
          .whereType<Map<String, dynamic>>()
          .map((m) => Spot.fromMap(m))
          .toList();

      return {
        'spots': spots,
        'totalCount':
            (responseData['totalCount'] as num?)?.toInt() ?? spots.length,
        'shownCount':
            (responseData['shownCount'] as num?)?.toInt() ?? spots.length,
        'averageWilson':
            (responseData['averageWilson'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error getting top ranked spots in bounds: $e');
      return {
        'spots': <Spot>[],
        'totalCount': 0,
        'shownCount': 0,
        'averageWilson': 0.0,
      };
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

      debugPrint(
        '✅ Found ${spots.length} spots for source $sourceId last updated before ${timestamp.day}/${timestamp.month}/${timestamp.year}',
      );

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

  // Get removed spots by source (admin function)
  // If sourceId is null, returns removed spots from all sources
  // If sourceId is empty string, returns removed spots with no source (shouldn't happen, but included for consistency)
  Future<List<Spot>> getRemovedSpotsBySource(String? sourceId) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('🔍 Searching for removed spots');
      if (sourceId != null) {
        debugPrint(
          '📦 Source filter: ${sourceId.isEmpty ? "Native spots (no source)" : sourceId}',
        );
      } else {
        debugPrint('📦 Source filter: All sources');
      }

      Query query = _firestore.collection('spots');

      // Filter by removed status
      query = query.where('spotSourceRemoved', isEqualTo: true);

      // Filter by source if specified
      if (sourceId != null) {
        if (sourceId.isNotEmpty) {
          query = query.where('spotSource', isEqualTo: sourceId);
        } else {
          // If sourceId is empty, get spots with no source (native spots)
          query = query.where('spotSource', isNull: true);
        }
      }
      // If sourceId is null, don't filter by source (get removed spots from all sources)

      // Order by removal date (most recently removed first)
      query = query.orderBy('spotSourceRemovedAt', descending: true);

      final querySnapshot = await query.get();

      final spots = querySnapshot.docs
          .map((doc) => Spot.fromFirestore(doc))
          .toList();

      debugPrint('✅ Found ${spots.length} removed spots');

      return spots;
    } catch (e) {
      _error = 'Failed to fetch removed spots: $e';
      debugPrint('Error fetching removed spots: $e');
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

      return {'deleted': deletedCount, 'failed': failedCount};
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
          .where(
            'duplicateOf',
            isNull: true,
          ); // Exclude spots that are already duplicates

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
          final descriptionMatch = spot.description.toLowerCase().contains(
            queryLower,
          );
          final addressMatch =
              spot.address?.toLowerCase().contains(queryLower) ?? false;
          final cityMatch =
              spot.city?.toLowerCase().contains(queryLower) ?? false;
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
    String? reportId,
    String? notes,
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

      // Prevent marking a spot as duplicate if other spots are already marked as duplicates of it
      final existingDuplicates = await getDuplicatesOfSpot(spotId);
      if (existingDuplicates.isNotEmpty) {
        _error =
            'Cannot mark this spot as a duplicate because other spots are already marked as duplicates of it';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Prevent circular references (check if original is already marked as duplicate)
      if (originalSpot.duplicateOf != null) {
        _error =
            'Cannot mark as duplicate of a spot that is already a duplicate';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Ensure the original spot is a native parkour.spot spot (not from external source)
      if (originalSpot.spotSource != null) {
        _error =
            'Original spot must be a native parkour.spot spot, not from an external source';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final originalSpotUpdates = buildSpotDuplicateMergeUpdates(
        original: originalSpot,
        duplicate: duplicateSpot,
        transferPhotos: transferPhotos,
        transferYoutubeLinks: transferYoutubeLinks,
        overwriteName: overwriteName,
        overwriteDescription: overwriteDescription,
        overwriteLocation: overwriteLocation,
        overwriteSpotAttributes: overwriteSpotAttributes,
      );

      if (originalSpotUpdates.isNotEmpty) {
        originalSpotUpdates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('spots')
            .doc(originalSpotId)
            .update(originalSpotUpdates);
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
          reportId: reportId,
          notes: notes,
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

  /// Streams the number of duplicates with pending post-link changes.
  Stream<int> watchDuplicatePendingChangesCount() {
    return _duplicatePendingChangesCountStream ??= replayLatest(
      _firestore
          .collection('spots')
          .where('duplicateHasPendingChanges', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.length),
      onValue: (count) => _duplicatePendingChangesCount = count,
    );
  }

  /// Live list of duplicates whose transferable fields changed after linking.
  Stream<List<Spot>> watchDuplicatePendingChangeSpots() {
    return _firestore
        .collection('spots')
        .where('duplicateHasPendingChanges', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final spots = snapshot.docs.map(Spot.fromFirestore).toList();
          spots.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return spots;
        });
  }

  /// Copies selected changed fields from a duplicate onto its native original,
  /// then acknowledges the remaining changes (same as dismiss).
  Future<bool> applyDuplicatePendingChanges({
    required String duplicateSpotId,
    bool transferPhotos = false,
    bool transferYoutubeLinks = false,
    bool overwriteName = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSpotAttributes = false,
    String? userId,
    String? userName,
  }) {
    return _reviewDuplicatePendingChanges(
      duplicateSpotId: duplicateSpotId,
      applySelected: true,
      transferPhotos: transferPhotos,
      transferYoutubeLinks: transferYoutubeLinks,
      overwriteName: overwriteName,
      overwriteDescription: overwriteDescription,
      overwriteLocation: overwriteLocation,
      overwriteSpotAttributes: overwriteSpotAttributes,
      userId: userId,
      userName: userName,
    );
  }

  /// Acknowledges pending duplicate field changes without updating the original.
  Future<bool> dismissDuplicatePendingChanges({
    required String duplicateSpotId,
    String? userId,
    String? userName,
  }) {
    return _reviewDuplicatePendingChanges(
      duplicateSpotId: duplicateSpotId,
      applySelected: false,
      userId: userId,
      userName: userName,
    );
  }

  Future<bool> _reviewDuplicatePendingChanges({
    required String duplicateSpotId,
    required bool applySelected,
    bool transferPhotos = false,
    bool transferYoutubeLinks = false,
    bool overwriteName = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSpotAttributes = false,
    String? userId,
    String? userName,
  }) async {
    _error = null;
    notifyListeners();
    final trimmedDup = duplicateSpotId.trim();
    if (trimmedDup.isEmpty) {
      _error = 'Invalid spot id';
      notifyListeners();
      return false;
    }

    try {
      final duplicate = await getSpotById(trimmedDup);
      if (duplicate == null) {
        _error = 'Spot not found';
        notifyListeners();
        return false;
      }
      final originalId = duplicate.duplicateOf?.trim();
      if (originalId == null || originalId.isEmpty) {
        _error = 'This spot is not marked as a duplicate';
        notifyListeners();
        return false;
      }

      final original = await getSpotById(originalId);
      if (original == null) {
        _error = 'Original spot not found';
        notifyListeners();
        return false;
      }
      if (!spotIsNative(original)) {
        _error =
            'The original must be a native parkour.spot spot, not from an external source';
        notifyListeners();
        return false;
      }

      if (applySelected) {
        final originalUpdates = buildSpotDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
          transferPhotos: transferPhotos,
          transferYoutubeLinks: transferYoutubeLinks,
          overwriteName: overwriteName,
          overwriteDescription: overwriteDescription,
          overwriteLocation: overwriteLocation,
          overwriteSpotAttributes: overwriteSpotAttributes,
        );
        if (originalUpdates.isNotEmpty) {
          originalUpdates['updatedAt'] = FieldValue.serverTimestamp();
          await _firestore
              .collection('spots')
              .doc(originalId)
              .update(originalUpdates);
        }
      }

      await _firestore
          .collection('spots')
          .doc(trimmedDup)
          .update(buildSpotDuplicateReviewAcknowledgedUpdates(duplicate));

      if (userId != null && userName != null) {
        await _auditLogService.logSpotDuplicateChangesReviewed(
          spotId: trimmedDup,
          originalSpotId: originalId,
          applied: applySelected,
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

      notifyListeners();
      return true;
    } catch (e, st) {
      _error = applySelected
          ? 'Failed to apply duplicate changes'
          : 'Failed to dismiss duplicate changes';
      debugPrint('SpotService._reviewDuplicatePendingChanges error: $e\n$st');
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

      return querySnapshot.docs.map((doc) => Spot.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting duplicates of spot: $e');
      return [];
    }
  }

  Query<Map<String, dynamic>> _spotsQueryWithinGeoBounds(
    Query<Map<String, dynamic>> query,
    Map<String, double> bounds,
  ) {
    return query
        .where('latitude', isGreaterThanOrEqualTo: bounds['minLat'])
        .where('latitude', isLessThanOrEqualTo: bounds['maxLat'])
        .where('longitude', isGreaterThanOrEqualTo: bounds['minLng'])
        .where('longitude', isLessThanOrEqualTo: bounds['maxLng']);
  }

  Future<List<Spot>> getNearbyDuplicateCandidates(
    Spot spot, {
    int maxDistanceMeters = 50,
    int limit = 50,
  }) async {
    final spotId = spot.id;
    if (spotId == null) return [];

    try {
      final bounds = boundsForRadiusMeters(
        latitude: spot.latitude,
        longitude: spot.longitude,
        radiusMeters: maxDistanceMeters,
      );

      // Match getTopSpotsInBounds: geo bounds in Firestore, circle refined in memory.
      final query = _spotsQueryWithinGeoBounds(
        _firestore
            .collection('spots')
            .where('duplicateOf', isEqualTo: null)
            .where('hidden', isEqualTo: false),
        bounds,
      );

      final snapshot = await query.limit(limit).get();

      final candidates = <Spot>[];
      for (final doc in snapshot.docs) {
        if (doc.id == spotId) continue;
        final candidate = Spot.fromFirestore(doc);
        final distance = distanceMeters(
          spot.latitude,
          spot.longitude,
          candidate.latitude,
          candidate.longitude,
        );
        if (distance <= maxDistanceMeters) {
          candidates.add(candidate);
        }
      }

      candidates.sort((a, b) {
        final aDistance = distanceMeters(
          spot.latitude,
          spot.longitude,
          a.latitude,
          a.longitude,
        );
        final bDistance = distanceMeters(
          spot.latitude,
          spot.longitude,
          b.latitude,
          b.longitude,
        );
        return aDistance.compareTo(bDistance);
      });
      return candidates;
    } catch (e) {
      debugPrint('Error loading nearby duplicate candidates: $e');
      return [];
    }
  }

  Future<List<Spot>> findDuplicateClusterFromSeeds(
    Iterable<String> seedSpotIds, {
    int maxDistanceMeters = 50,
  }) async {
    final spotsById = <String, Spot>{};
    final queue = <Spot>[];

    Future<void> addSpot(Spot? spot) async {
      final id = spot?.id;
      if (spot == null || id == null || spotsById.containsKey(id)) return;
      spotsById[id] = spot;
      queue.add(spot);
    }

    for (final spotId in seedSpotIds.toSet()) {
      await addSpot(await getSpotById(spotId));
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentId = current.id;
      if (currentId == null) continue;

      for (final linkedDuplicate in await getDuplicatesOfSpot(currentId)) {
        await addSpot(linkedDuplicate);
      }

      for (final nearby in await getNearbyDuplicateCandidates(
        current,
        maxDistanceMeters: maxDistanceMeters,
      )) {
        await addSpot(nearby);
      }
    }

    final spots = spotsById.values.toList();
    spots.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return spots;
  }

  Future<String?> resolveDuplicateClusterToNative({
    required List<Spot> clusterSpots,
    required Spot previewSpot,
    required String basisSpotId,
    required String userId,
    required String userName,
    String? runId,
    List<int> resolvedPairIndices = const [],
    String? reportId,
    String? notes,
  }) async {
    final memberIds = clusterSpots
        .map((spot) => spot.id)
        .whereType<String>()
        .toSet();
    if (memberIds.length < 2) {
      _error = 'At least two spots are required to resolve a duplicate cluster';
      notifyListeners();
      return null;
    }

    if (!memberIds.contains(basisSpotId)) {
      _error = 'Basis spot must be included in the duplicate cluster';
      notifyListeners();
      return null;
    }

    if (clusterSpots.any(isSpotAlreadyMarkedAsDuplicate)) {
      _error =
          'Cannot merge spots that are already marked as duplicates of another spot';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final duplicateIdsToUpdate = <String>{...memberIds};
      for (final memberId in memberIds) {
        final linkedDuplicates = await getDuplicatesOfSpot(memberId);
        duplicateIdsToUpdate.addAll(
          linkedDuplicates.map((spot) => spot.id).whereType<String>(),
        );
      }

      final basisSpot = clusterSpots.firstWhere(
        (spot) => spot.id == basisSpotId,
      );
      final updateExistingNative = isParkourSpotNativeSpot(basisSpot);
      final batch = _firestore.batch();
      final sortedMemberIds = memberIds.toList()..sort();
      late final String targetId;
      Spot? oldBasisSpot;

      if (updateExistingNative) {
        targetId = basisSpotId;
        oldBasisSpot = basisSpot;
        duplicateIdsToUpdate.remove(basisSpotId);

        final updatedSpot = basisSpot.copyWith(
          name: previewSpot.name,
          description: previewSpot.description,
          latitude: previewSpot.latitude,
          longitude: previewSpot.longitude,
          address: previewSpot.address,
          city: previewSpot.city,
          countryCode: previewSpot.countryCode,
          imageUrls: previewSpot.imageUrls,
          youtubeVideoIds: previewSpot.youtubeVideoIds,
          spotAccess: previewSpot.spotAccess,
          spotFeatures: previewSpot.spotFeatures,
          spotFacilities: previewSpot.spotFacilities,
          goodFor: previewSpot.goodFor,
          updatedAt: DateTime.now(),
        );

        batch.update(
          _firestore.collection('spots').doc(targetId),
          updatedSpot.toFirestore(isUpdate: true),
        );
      } else {
        final nativeRef = _firestore.collection('spots').doc();
        targetId = nativeRef.id;
        final now = DateTime.now();
        final nativeSpot = Spot(
          name: previewSpot.name,
          description: previewSpot.description,
          latitude: previewSpot.latitude,
          longitude: previewSpot.longitude,
          address: previewSpot.address,
          city: previewSpot.city,
          countryCode: previewSpot.countryCode,
          imageUrls: previewSpot.imageUrls,
          youtubeVideoIds: previewSpot.youtubeVideoIds,
          createdBy: userId,
          createdByName: userName,
          createdAt: now,
          updatedAt: now,
          averageRating: 0,
          ratingCount: 0,
          wilsonLowerBound: 0,
          ranking: previewSpot.ranking ?? Random().nextDouble(),
          spotAccess: previewSpot.spotAccess,
          spotFeatures: previewSpot.spotFeatures,
          spotFacilities: previewSpot.spotFacilities,
          goodFor: previewSpot.goodFor,
          duplicateOf: null,
          hidden: false,
          createdFromCreateNative: true,
        );

        batch.set(nativeRef, nativeSpot.toFirestore());
      }

      for (final duplicateId in duplicateIdsToUpdate) {
        batch.update(_firestore.collection('spots').doc(duplicateId), {
          'duplicateOf': targetId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (runId != null) {
        final resolution = {
          'status': 'resolved_to_native',
          'nativeSpotId': targetId,
          'clusterSpotIds': sortedMemberIds,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': userId,
          'resolvedByName': userName,
          if (notes?.isNotEmpty ?? false) 'notes': notes,
          if (reportId?.isNotEmpty ?? false) 'reportId': reportId,
        };
        final runUpdates = <String, dynamic>{
          'collapsedPairs': FieldValue.arrayUnion(resolvedPairIndices),
        };
        for (final pairIndex in resolvedPairIndices) {
          runUpdates['pairResolutions.$pairIndex'] = resolution;
        }
        batch.update(
          _firestore.collection('duplicateDetectionResults').doc(runId),
          runUpdates,
        );
      }

      await batch.commit();

      for (final duplicateId in duplicateIdsToUpdate) {
        await _auditLogService.logSpotMarkedAsDuplicate(
          spotId: duplicateId,
          originalSpotId: targetId,
          userId: userId,
          userName: userName,
          reportId: reportId,
          notes: notes,
        );
      }

      if (updateExistingNative && oldBasisSpot != null) {
        final updatedSpot = oldBasisSpot.copyWith(
          name: previewSpot.name,
          description: previewSpot.description,
          latitude: previewSpot.latitude,
          longitude: previewSpot.longitude,
          address: previewSpot.address,
          city: previewSpot.city,
          countryCode: previewSpot.countryCode,
          imageUrls: previewSpot.imageUrls,
          youtubeVideoIds: previewSpot.youtubeVideoIds,
          spotAccess: previewSpot.spotAccess,
          spotFeatures: previewSpot.spotFeatures,
          spotFacilities: previewSpot.spotFacilities,
          goodFor: previewSpot.goodFor,
        );
        final changes = _computeSpotChanges(oldBasisSpot, updatedSpot);
        changes['updatedFromDuplicateCluster'] = {
          'from': null,
          'to': sortedMemberIds,
        };
        await _auditLogService.logSpotEdit(
          spotId: targetId,
          userId: userId,
          userName: userName,
          reportId: reportId,
          notes: notes,
          changes: changes,
          metadata: {
            'sourceSpotIds': sortedMemberIds,
            'resolvedPairIndices': resolvedPairIndices,
          },
        );
      } else {
        await _auditLogService.logSpotEdit(
          spotId: targetId,
          userId: userId,
          userName: userName,
          reportId: reportId,
          notes: notes,
          changes: {
            'createdFromDuplicateCluster': {
              'from': null,
              'to': sortedMemberIds,
            },
          },
          metadata: {
            'sourceSpotIds': sortedMemberIds,
            'resolvedPairIndices': resolvedPairIndices,
          },
        );
      }

      _isLoading = false;
      notifyListeners();
      return targetId;
    } catch (e) {
      _error = 'Failed to resolve duplicate cluster: $e';
      debugPrint('Error resolving duplicate cluster: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Hide or unhide a spot (moderator only)
  Future<bool> setSpotHidden(
    String spotId,
    bool hidden, {
    String? userId,
    String? userName,
    String? reportId,
    String? notes,
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
          reportId: reportId,
          notes: notes,
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

  // Find all spots with duplicate image URLs in their imageUrls array
  Future<List<Spot>> findSpotsWithDuplicateImageUrls() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get all spots that have imageUrls
      final querySnapshot = await _firestore
          .collection('spots')
          .where('imageUrls', isNull: false)
          .get();

      final spotsWithDuplicates = <Spot>[];

      for (final doc in querySnapshot.docs) {
        final spot = Spot.fromFirestore(doc);
        if (spot.imageUrls != null && spot.imageUrls!.isNotEmpty) {
          // Check for duplicates by comparing the list length with the set length
          final uniqueUrls = spot.imageUrls!.toSet();
          if (spot.imageUrls!.length != uniqueUrls.length) {
            spotsWithDuplicates.add(spot);
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return spotsWithDuplicates;
    } catch (e) {
      _error = 'Failed to find spots with duplicate image URLs: $e';
      debugPrint('Error finding spots with duplicate image URLs: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Result for spots whose images lack resized versions.
  static const String missingResizedImagesErrorCode = 'object-not-found';

  /// Find all spots that have at least one image without a resized version.
  /// Returns a list of (spot, list of image URLs missing resized versions).
  Future<List<SpotWithMissingResizedImages>> findSpotsWithMissingResizedImages({
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('spots')
          .where('imageUrls', isNull: false)
          .get();

      final results = <SpotWithMissingResizedImages>[];
      var imagesChecked = 0;
      var totalToCheck = 0;
      for (final doc in querySnapshot.docs) {
        final spot = Spot.fromFirestore(doc);
        if (spot.imageUrls != null) {
          for (final url in spot.imageUrls!) {
            if (getResizedPathInfo(url) != null) totalToCheck++;
          }
        }
      }

      for (final doc in querySnapshot.docs) {
        final spot = Spot.fromFirestore(doc);
        if (spot.imageUrls == null || spot.imageUrls!.isEmpty) continue;

        final missingUrls = <String>[];
        for (final url in spot.imageUrls!) {
          final info = getResizedPathInfo(url);
          if (info == null) continue;

          // Consider "has resized" if any candidate exists (1200x1200 or 1200x630)
          bool hasResized = false;
          for (final candidatePath in info.resizedPathCandidates) {
            try {
              final ref = _storage.ref().child(candidatePath);
              await ref.getMetadata();
              hasResized = true;
              break;
            } on FirebaseException catch (e) {
              if (e.code != missingResizedImagesErrorCode) {
                debugPrint('Storage error checking $candidatePath: ${e.code}');
              }
            }
          }
          if (!hasResized) {
            missingUrls.add(url);
          }

          imagesChecked++;
          onProgress?.call(imagesChecked, totalToCheck);
          await Future<void>.delayed(Duration.zero);
        }

        if (missingUrls.isNotEmpty) {
          results.add(
            SpotWithMissingResizedImages(
              spot: spot,
              missingImageUrls: missingUrls,
            ),
          );
        }
      }

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      _error = 'Failed to find spots with missing resized images: $e';
      debugPrint('Error finding spots with missing resized images: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Trigger the storage-resize-images extension for one spot's images (admin only).
  Future<Map<String, dynamic>> triggerResizeForSpot(String spotId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'triggerResizeForSpot',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
      );

      final result = await callable.call({'spotId': spotId});
      final data = result.data as Map<String, dynamic>?;

      _isLoading = false;
      notifyListeners();

      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] as String? ?? 'Unknown error');
      }
      return data;
    } catch (e) {
      _error = 'Failed to trigger resize: $e';
      debugPrint('Error triggering resize for spot: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Trigger the storage-resize-images extension for images missing resized versions.
  /// Re-uploads each image to the same path to fire object.finalize (admin only).
  /// Returns result with triggered/verified counts and per-image success/failure.
  Future<Map<String, dynamic>> triggerResizeForMissingImages() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'triggerResizeForMissingImages',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>?;

      _isLoading = false;
      notifyListeners();

      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] as String? ?? 'Unknown error');
      }
      return data;
    } catch (e) {
      _error = 'Failed to trigger resize: $e';
      debugPrint('Error triggering resize for missing images: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Find potential duplicate spots (admin only)
  Future<Map<String, dynamic>> findDuplicateSpots({
    required String sourceId,
    int maxDistanceMeters = 50,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable(
        'findDuplicateSpots',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );

      final result = await callable.call({
        'sourceId': sourceId,
        'maxDistanceMeters': maxDistanceMeters,
      });

      final responseData = result.data as Map<String, dynamic>?;
      if (responseData == null || responseData['success'] != true) {
        throw Exception(
          responseData != null && responseData['error'] is String
              ? responseData['error']
              : 'Unknown error',
        );
      }

      _isLoading = false;
      notifyListeners();

      return {
        'runId': responseData['runId'] as String?,
        'pairsFound': (responseData['pairsFound'] as num?)?.toInt() ?? 0,
        'spotsChecked': (responseData['spotsChecked'] as num?)?.toInt() ?? 0,
        'spotsSkipped': (responseData['spotsSkipped'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      _error = 'Failed to find duplicate spots: $e';
      debugPrint('Error finding duplicate spots: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// A spot with image URLs that lack resized versions in Firebase Storage.
class SpotWithMissingResizedImages {
  const SpotWithMissingResizedImages({
    required this.spot,
    required this.missingImageUrls,
  });

  final Spot spot;
  final List<String> missingImageUrls;
}
