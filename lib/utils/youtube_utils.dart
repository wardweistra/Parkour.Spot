/// YouTube video ID and thumbnail helpers (no Flutter imports — safe for VM tests).
library;

final _bareYoutubeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{6,}$');

/// Extracts a YouTube video ID from a raw ID or watch/embed/shorts/youtu.be URL.
///
/// Returns the trimmed input when it is non-empty but not recognized as a URL,
/// matching existing spot parse behavior.
String? extractYoutubeVideoId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (_bareYoutubeIdPattern.hasMatch(trimmed) && !trimmed.contains('/')) {
    return trimmed;
  }
  try {
    final uri = Uri.parse(trimmed);
    if (uri.host.contains('youtu.be')) {
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (seg != null && seg.isNotEmpty) return seg;
    }
    final vParam = uri.queryParameters['v'];
    if (vParam != null && vParam.isNotEmpty) return vParam;
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex != -1 && embedIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments[embedIndex + 1];
    }
    final shortsIndex = uri.pathSegments.indexOf('shorts');
    if (shortsIndex != -1 && shortsIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments[shortsIndex + 1];
    }
  } catch (_) {}
  return trimmed;
}

/// Parses a Firestore `youtubeVideoIds` value into a list of video IDs.
List<String>? extractYoutubeVideoIdsFromValue(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value
        .whereType<dynamic>()
        .map((e) => e.toString())
        .map(extractYoutubeVideoId)
        .whereType<String>()
        .toList();
  }
  if (value is String) {
    final id = extractYoutubeVideoId(value);
    return id == null ? null : <String>[id];
  }
  return null;
}

/// YouTube thumbnail URL for [videoId]. Import uses `maxresdefault`.
String youtubeThumbnailUrl(
  String videoId, {
  String quality = 'maxresdefault',
}) {
  return 'https://img.youtube.com/vi/$videoId/$quality.jpg';
}

/// Smaller thumbnail used for edit-screen previews (always present for valid IDs).
String youtubePreviewThumbnailUrl(String videoId) =>
    youtubeThumbnailUrl(videoId, quality: 'hqdefault');

/// True when [url] is a YouTube CDN thumbnail for [videoId].
bool imageUrlIsYoutubeThumbnail(String url, String videoId) {
  return url.contains('img.youtube.com/vi/$videoId/') ||
      url.contains('i.ytimg.com/vi/$videoId/');
}

/// Newly added video IDs that do not already have a YouTube CDN thumbnail in photos.
List<String> youtubeIdsNeedingThumbnails({
  required List<String> previousIds,
  required List<String> nextIds,
  List<String> existingImageUrls = const [],
}) {
  final previous = previousIds.toSet();
  final seen = <String>{};
  final result = <String>[];
  for (final rawId in nextIds) {
    final id = rawId.trim();
    if (id.isEmpty || previous.contains(id) || !seen.add(id)) continue;
    final alreadyHasThumbnail = existingImageUrls.any(
      (url) => imageUrlIsYoutubeThumbnail(url, id),
    );
    if (!alreadyHasThumbnail) {
      result.add(id);
    }
  }
  return result;
}

/// Appends thumbnail URLs for [videoIds], using [resolvedUrls] when present.
List<String> appendYoutubeThumbnails({
  required List<String> imageUrls,
  required List<String> videoIds,
  Map<String, String> resolvedUrls = const {},
}) {
  final result = List<String>.from(imageUrls);
  for (final rawId in videoIds) {
    final id = rawId.trim();
    if (id.isEmpty) continue;
    if (result.any((url) => imageUrlIsYoutubeThumbnail(url, id))) continue;
    final resolved = resolvedUrls[id];
    result.add(
      (resolved != null && resolved.isNotEmpty)
          ? resolved
          : youtubeThumbnailUrl(id),
    );
  }
  return result;
}
