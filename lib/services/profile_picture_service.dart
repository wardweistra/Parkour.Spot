import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import '../utils/image_preparation.dart';

class ProfilePictureService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crop image to square (center crop) and resize to max 800x800
  /// Expects bytes from [prepareImageForUpload] (JPEG, PNG, GIF, or WebP).
  /// Returns the processed image bytes as JPEG.
  Future<Uint8List> _cropAndResizeImage(Uint8List imageBytes) async {
    try {
      // Decode the image
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image. The image file may be corrupted or in an unsupported format.');
      }

      // Validate image dimensions
      if (originalImage.width <= 0 || originalImage.height <= 0) {
        throw Exception('Invalid image dimensions.');
      }

      final width = originalImage.width;
      final height = originalImage.height;

      // Determine the size for square crop (use smallest dimension)
      final cropSize = width < height ? width : height;

      // Calculate crop coordinates (center crop)
      final x = (width - cropSize) ~/ 2;
      final y = (height - cropSize) ~/ 2;

      // Crop to square
      final croppedImage = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );

      // Resize to max 800x800 if larger
      final resizedImage = croppedImage.width > 800 || croppedImage.height > 800
          ? img.copyResize(
              croppedImage,
              width: 800,
              height: 800,
              interpolation: img.Interpolation.linear,
            )
          : croppedImage;

      // Encode as JPEG with 85% quality
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      
      if (jpegBytes.isEmpty) {
        throw Exception('Failed to encode image as JPEG.');
      }

      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      debugPrint('Error cropping/resizing image: $e');
      // Provide more helpful error message
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to process image: ${e.toString()}');
    }
  }


  /// Upload profile picture from File (mobile)
  /// [onProgress] callback receives progress value 0.0 to 1.0
  Future<String> uploadProfilePicture(
    File imageFile, {
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Step 1: Read file as bytes (10% of progress)
      onProgress?.call(0.1);
      
      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final imageBytes = await imageFile.readAsBytes();

      // Validate we got bytes
      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      debugPrint('Read ${imageBytes.length} bytes from image file');

      // Step 2: Prepare (validate, convert HEIC) then crop and resize
      onProgress?.call(0.2);
      final prepared = await prepareImageForUpload(imageBytes);
      onProgress?.call(0.3);
      final processedBytes = await _cropAndResizeImage(prepared.bytes);

      // Step 3: Upload to Firebase Storage (30-100% of progress)
      onProgress?.call(0.3);
      final fileName = 'users/${user.uid}/profile.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        processedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Map upload progress from 30% to 90% (leaving 10% for getting download URL)
        onProgress?.call(0.3 + (progress * 0.6));
      });

      final snapshot = await uploadTask;
      
      // Step 4: Get download URL (90-100% of progress)
      onProgress?.call(0.9);
      final downloadURL = await snapshot.ref.getDownloadURL();
      onProgress?.call(1.0);
      
      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Upload profile picture from Uint8List (web)
  /// [onProgress] callback receives progress value 0.0 to 1.0
  Future<String> uploadProfilePictureBytes(
    Uint8List imageBytes, {
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Validate we got bytes
      if (imageBytes.isEmpty) {
        throw Exception('Image data is empty');
      }

      debugPrint('Processing ${imageBytes.length} bytes of image data');

      // Step 1: Prepare (validate, convert HEIC) then crop and resize
      onProgress?.call(0.2);
      final prepared = await prepareImageForUpload(imageBytes);
      onProgress?.call(0.3);
      final processedBytes = await _cropAndResizeImage(prepared.bytes);

      // Step 2: Upload to Firebase Storage (30-90% of progress)
      onProgress?.call(0.3);
      final fileName = 'users/${user.uid}/profile.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        processedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Map upload progress from 30% to 90% (leaving 10% for getting download URL)
        onProgress?.call(0.3 + (progress * 0.6));
      });

      final snapshot = await uploadTask;
      
      // Step 3: Get download URL (90-100% of progress)
      onProgress?.call(0.9);
      final downloadURL = await snapshot.ref.getDownloadURL();
      onProgress?.call(1.0);
      
      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Delete profile picture from Firebase Storage
  Future<void> deleteProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final fileName = 'users/${user.uid}/profile.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.delete();
    } catch (e) {
      // If file doesn't exist, that's okay - just log it
      debugPrint('Error deleting profile picture (may not exist): $e');
    }
  }

  /// Download image from URL and upload to Firebase Storage as profile picture
  /// This is used to copy Google profile pictures to our Storage
  /// Returns the Firebase Storage URL
  Future<String> copyImageFromUrl(String imageUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Download image from URL
      debugPrint('Downloading profile picture from: $imageUrl');
      
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image: HTTP ${response.statusCode}');
      }

      final imageBytes = response.bodyBytes;
      if (imageBytes.isEmpty) {
        throw Exception('Downloaded image is empty');
      }

      debugPrint('Downloaded ${imageBytes.length} bytes');

      // Prepare (validate, convert HEIC) then crop and resize
      final prepared = await prepareImageForUpload(imageBytes);
      final processedBytes = await _cropAndResizeImage(prepared.bytes);

      // Upload to Firebase Storage
      final fileName = 'users/${user.uid}/profile.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        processedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();
      
      debugPrint('Successfully copied profile picture to Storage: $downloadURL');
      return downloadURL;
    } catch (e) {
      debugPrint('Error copying image from URL: $e');
      rethrow;
    }
  }

  /// Check if a URL is a Google profile picture URL.
  /// Only checks googleusercontent.com; googleapis.com is excluded because
  /// Firebase Storage URLs (storage.googleapis.com, firebasestorage.googleapis.com)
  /// also contain it and would be falsely matched.
  bool isGoogleProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('googleusercontent.com');
  }

  /// Check if a URL is a Firebase Storage profile picture URL
  bool isFirebaseStorageProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final user = _auth.currentUser;
    if (user == null) return false;
    return url.contains('users/${user.uid}/') && 
           (url.contains('firebasestorage.googleapis.com') || 
            url.contains('storage.googleapis.com'));
  }
}
