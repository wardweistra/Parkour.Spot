/// Utility functions for working with image URLs, particularly for converting
/// full-size images to resized versions for better performance.

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
        // Get the encoded path (e.g., "spots%2Ffilename.jpg")
        final encodedPath = uri.pathSegments[oIndex + 1];
        final decodedPath = Uri.decodeComponent(encodedPath);
        
        // Check if it's in the spots folder and not already resized
        if (decodedPath.startsWith('spots/') && !decodedPath.startsWith('spots/resized/')) {
          // Extract filename and create resized path
          final filename = decodedPath.split('/').last;
          final baseName = filename.split('.').first; // Remove extension
          final resizedPath = 'spots/resized/${baseName}_1200x630.webp';
          final encodedResizedPath = Uri.encodeComponent(resizedPath);
          
          // Replace the encoded path in the original URL string to avoid double encoding
          // Find the position of the encoded path in the original URL
          final pathStart = originalUrl.indexOf(encodedPath);
          if (pathStart != -1) {
            // Replace the encoded path with the new encoded resized path
            final beforePath = originalUrl.substring(0, pathStart);
            final afterPath = originalUrl.substring(pathStart + encodedPath.length);
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

