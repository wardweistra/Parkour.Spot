/// Utility functions for working with image URLs, particularly for converting
/// full-size images to resized versions for better performance.
library;

/// Result of parsing a spot image URL for resized path checking.
class ResizedPathInfo {
  const ResizedPathInfo({
    required this.originalPath,
    required this.resizedPath,
  });

  /// Original storage path (e.g. spots/filename.jpg)
  final String originalPath;

  /// Expected resized storage path (e.g. spots/resized/filename_1200x630.webp)
  final String resizedPath;
}

/// Parses a Firebase Storage spot image URL and returns the expected resized path.
/// Returns null if the URL is not a spots/ image (external URL, already resized, etc).
ResizedPathInfo? getResizedPathInfo(String originalUrl) {
  try {
    if (!originalUrl.contains('storage.googleapis.com') &&
        !originalUrl.contains('firebasestorage.googleapis.com')) {
      return null;
    }

    final uri = Uri.parse(originalUrl);

    // Handle the encoded format: firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Ffilename.jpg
    if (uri.pathSegments.contains('o')) {
      final oIndex = uri.pathSegments.indexOf('o');
      if (oIndex != -1 && oIndex + 1 < uri.pathSegments.length) {
        final encodedPath = uri.pathSegments[oIndex + 1];
        final decodedPath = Uri.decodeComponent(encodedPath);
        if (decodedPath.startsWith('spots/') &&
            !decodedPath.startsWith('spots/resized/')) {
          final filename = decodedPath.split('/').last;
          final baseName = filename.split('.').first;
          final resizedPath = 'spots/resized/${baseName}_1200x630.webp';
          return ResizedPathInfo(originalPath: decodedPath, resizedPath: resizedPath);
        }
      }
      return null;
    }

    // Handle storage.googleapis.com format: .../bucket/spots/filename.jpg
    final pathSegments = uri.pathSegments;
    final spotsIndex = pathSegments.indexOf('spots');
    if (spotsIndex != -1 &&
        spotsIndex + 1 < pathSegments.length &&
        pathSegments[spotsIndex + 1] != 'resized') {
      final filename = pathSegments[spotsIndex + 1];
      final baseName = filename.split('.').first;
      final originalPath = 'spots/$filename';
      final resizedPath = 'spots/resized/${baseName}_1200x630.webp';
      return ResizedPathInfo(originalPath: originalPath, resizedPath: resizedPath);
    }

    return null;
  } catch (_) {
    return null;
  }
}

/// Converts a full-size Firebase Storage image URL to its resized version.
/// 
/// The storage-resize-images extension creates resized images in the format:
/// `spots/resized/baseName_1200x630.webp`
/// 
/// This function handles Firebase Storage URL formats:
/// - `https://storage.googleapis.com/bucket-name/spots/filename.jpg`
/// - `https://firebasestorage.googleapis.com/v0/b/bucket-name/o/spots%2Ffilename.jpg?alt=media&token=...`
/// 
/// Returns the original URL if it's not a Firebase Storage URL or if conversion fails.
String getResizedImageUrl(String originalUrl) {
  try {
    // Check if this is a Firebase Storage URL
    if (!originalUrl.contains('storage.googleapis.com') && 
        !originalUrl.contains('firebasestorage.googleapis.com')) {
      // Not a Firebase Storage URL, return as-is
      return originalUrl;
    }

    final uri = Uri.parse(originalUrl);
    
    // Handle the encoded format: firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Ffilename.jpg
    // This format is used by getDownloadURL() and includes query parameters
    if (uri.pathSegments.contains('o')) {
      final oIndex = uri.pathSegments.indexOf('o');
      
      if (oIndex != -1 && oIndex + 1 < uri.pathSegments.length) {
        // pathSegments returns DECODED segments (e.g. "spots/filename.jpg")
        // The original URL contains the encoded form (e.g. "spots%2Ffilename.jpg")
        final decodedPath = uri.pathSegments[oIndex + 1];
        
        // Check if it's in the spots folder and not already resized
        if (decodedPath.startsWith('spots/') && !decodedPath.startsWith('spots/resized/')) {
          // Extract filename and create resized path
          final filename = decodedPath.split('/').last;
          final baseName = filename.split('.').first; // Remove extension
          final resizedPath = 'spots/resized/${baseName}_1200x630.webp';
          final encodedResizedPath = Uri.encodeComponent(resizedPath);
          
          // Search for the path as it appears in the URL (encoded form).
          // pathSegments is decoded, but the URL string uses encoded slashes.
          final encodedPathInUrl = Uri.encodeComponent(decodedPath);
          final pathStart = originalUrl.indexOf(encodedPathInUrl);
          if (pathStart != -1) {
            // Replace the encoded path with the new encoded resized path
            final beforePath = originalUrl.substring(0, pathStart);
            final afterPath = originalUrl.substring(pathStart + encodedPathInUrl.length);
            return '$beforePath$encodedResizedPath$afterPath';
          }
        }
      }
    }
    
    // Handle the direct format: storage.googleapis.com/bucket-name/spots/filename.jpg
    final pathSegments = uri.pathSegments;
    final spotsIndex = pathSegments.indexOf('spots');
    
    if (spotsIndex != -1 && 
        spotsIndex + 1 < pathSegments.length &&
        pathSegments[spotsIndex + 1] != 'resized') {
      // Extract filename
      final filename = pathSegments[spotsIndex + 1];
      final baseName = filename.split('.').first; // Remove extension
      final resizedFilename = '${baseName}_1200x630.webp';
      
      // Replace spots/filename with spots/resized/resizedFilename
      final newPathSegments = List<String>.from(pathSegments);
      newPathSegments[spotsIndex + 1] = 'resized';
      // Insert the resized filename after 'resized'
      newPathSegments.insert(spotsIndex + 2, resizedFilename);
      
      return uri.replace(pathSegments: newPathSegments).toString();
    }
    
    // If we can't convert it, return the original
    return originalUrl;
  } catch (e) {
    // If anything goes wrong, return the original URL
    return originalUrl;
  }
}

