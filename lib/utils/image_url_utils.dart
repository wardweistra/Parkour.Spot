/// Utility functions for working with image URLs, particularly for converting
/// full-size images to resized versions for better performance.
library;

/// Result of parsing a spot image URL for resized path checking.
class ResizedPathInfo {
  const ResizedPathInfo({
    required this.originalPath,
    required this.resizedPath,
    required this.resizedPathCandidates,
  });

  /// Original storage path (e.g. spots/filename.jpg)
  final String originalPath;

  /// Primary resized storage path (e.g. spots/resized/filename_1200x1200.webp)
  final String resizedPath;

  /// Resized paths to check for existence, in priority order:
  /// [1200x1200, 1200x630]. Image "has resized" if any exists.
  final List<String> resizedPathCandidates;
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
          final resizedPath = 'spots/resized/${baseName}_1200x1200.webp';
          final candidates = [
            resizedPath,
            'spots/resized/${baseName}_1200x630.webp',
          ];
          return ResizedPathInfo(
            originalPath: decodedPath,
            resizedPath: resizedPath,
            resizedPathCandidates: candidates,
          );
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
      final resizedPath = 'spots/resized/${baseName}_1200x1200.webp';
      final candidates = [
        resizedPath,
        'spots/resized/${baseName}_1200x630.webp',
      ];
      return ResizedPathInfo(
        originalPath: originalPath,
        resizedPath: resizedPath,
        resizedPathCandidates: candidates,
      );
    }

    return null;
  } catch (_) {
    return null;
  }
}

/// Converts a full-size Firebase Storage image URL to a resized URL with the given size suffix.
/// Returns null if not a Firebase Storage spots URL or if already resized.
String? _toResizedUrl(String originalUrl, String sizeSuffix) {
  try {
    if (!originalUrl.contains('storage.googleapis.com') &&
        !originalUrl.contains('firebasestorage.googleapis.com')) {
      return null;
    }

    final uri = Uri.parse(originalUrl);

    if (uri.pathSegments.contains('o')) {
      final oIndex = uri.pathSegments.indexOf('o');
      if (oIndex != -1 && oIndex + 1 < uri.pathSegments.length) {
        final decodedPath = uri.pathSegments[oIndex + 1];
        if (decodedPath.startsWith('spots/') &&
            !decodedPath.startsWith('spots/resized/')) {
          final filename = decodedPath.split('/').last;
          final baseName = filename.split('.').first;
          final resizedPath = 'spots/resized/${baseName}_$sizeSuffix.webp';
          final encodedResizedPath = Uri.encodeComponent(resizedPath);
          final encodedPathInUrl = Uri.encodeComponent(decodedPath);
          final pathStart = originalUrl.indexOf(encodedPathInUrl);
          if (pathStart != -1) {
            final beforePath = originalUrl.substring(0, pathStart);
            final afterPath =
                originalUrl.substring(pathStart + encodedPathInUrl.length);
            return '$beforePath$encodedResizedPath$afterPath';
          }
        }
      }
      return null;
    }

    final pathSegments = uri.pathSegments;
    final spotsIndex = pathSegments.indexOf('spots');
    if (spotsIndex != -1 &&
        spotsIndex + 1 < pathSegments.length &&
        pathSegments[spotsIndex + 1] != 'resized') {
      final filename = pathSegments[spotsIndex + 1];
      final baseName = filename.split('.').first;
      final resizedFilename = '${baseName}_$sizeSuffix.webp';
      final newPathSegments = List<String>.from(pathSegments);
      newPathSegments[spotsIndex + 1] = 'resized';
      newPathSegments.insert(spotsIndex + 2, resizedFilename);
      return uri.replace(pathSegments: newPathSegments).toString();
    }

    return null;
  } catch (_) {
    return null;
  }
}

/// Returns URL candidates for loading a spot image, in priority order:
/// [1200x1200, 1200x630, original]. Use for fallback when 1200x1200 may not exist yet.
List<String> getResizedImageUrlCandidates(String originalUrl) {
  final url1200x1200 = _toResizedUrl(originalUrl, '1200x1200');
  final url1200x630 = _toResizedUrl(originalUrl, '1200x630');
  if (url1200x1200 != null) {
    final result = [url1200x1200];
    if (url1200x630 != null) result.add(url1200x630);
    result.add(originalUrl);
    return result;
  }
  return [originalUrl];
}

/// Converts a full-size Firebase Storage image URL to its resized version (1200x1200).
///
/// The storage-resize-images extension creates resized images in the format:
/// `spots/resized/baseName_1200x1200.webp`
///
/// This function handles Firebase Storage URL formats:
/// - `https://storage.googleapis.com/bucket-name/spots/filename.jpg`
/// - `https://firebasestorage.googleapis.com/v0/b/bucket-name/o/spots%2Ffilename.jpg?alt=media&token=...`
///
/// Returns the original URL if it's not a Firebase Storage URL or if conversion fails.
String getResizedImageUrl(String originalUrl) {
  return getResizedImageUrlCandidates(originalUrl).first;
}

