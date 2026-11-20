/// YouTube video ID and thumbnail helpers (no Flutter imports — safe for VM tests).
library;

import 'package:http/http.dart' as http;

final _bareYoutubeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{6,}$');
final _youtubeThumbnailUrlPattern = RegExp(
  r'(?:img\.youtube\.com|i\d*\.ytimg\.com)/vi/([a-zA-Z0-9_-]{6,20})/',
);

/// Thumbnail qualities to try, highest resolution first.
const youtubeThumbnailQualities = ['maxresdefault', 'sddefault', 'hqdefault'];

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

/// Title + channel for a linked YouTube video (from oEmbed, stored on the spot).
class YoutubeVideoMeta {
  const YoutubeVideoMeta({required this.title, required this.channelTitle});

  final String title;
  final String channelTitle;

  bool get hasDisplayTitle => title.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'title': title,
    'channelTitle': channelTitle,
  };

  factory YoutubeVideoMeta.fromMap(Map<String, dynamic> map) {
    return YoutubeVideoMeta(
      title: map['title']?.toString() ?? '',
      channelTitle:
          map['channelTitle']?.toString() ??
          map['author_name']?.toString() ??
          '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YoutubeVideoMeta &&
          title == other.title &&
          channelTitle == other.channelTitle;

  @override
  int get hashCode => Object.hash(title, channelTitle);
}

/// Parses Firestore `youtubeVideoMeta` (map of videoId → {title, channelTitle}).
Map<String, YoutubeVideoMeta>? extractYoutubeVideoMetaFromValue(dynamic value) {
  if (value == null || value is! Map) return null;
  final result = <String, YoutubeVideoMeta>{};
  value.forEach((key, raw) {
    final id = key?.toString().trim() ?? '';
    if (id.isEmpty || raw is! Map) return;
    final meta = YoutubeVideoMeta.fromMap(Map<String, dynamic>.from(raw));
    if (!meta.hasDisplayTitle && meta.channelTitle.trim().isEmpty) return;
    result[id] = meta;
  });
  return result.isEmpty ? null : result;
}

/// Keeps only meta entries whose keys are in [videoIds].
Map<String, YoutubeVideoMeta> pruneYoutubeVideoMeta({
  required Map<String, YoutubeVideoMeta>? meta,
  required List<String> videoIds,
}) {
  if (meta == null || meta.isEmpty) return const {};
  final keep = videoIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final result = <String, YoutubeVideoMeta>{};
  for (final entry in meta.entries) {
    if (keep.contains(entry.key)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

/// Video IDs that still need title/channel resolution.
List<String> youtubeIdsNeedingMeta({
  required List<String> videoIds,
  Map<String, YoutubeVideoMeta>? existingMeta,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final rawId in videoIds) {
    final id = rawId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    final meta = existingMeta?[id];
    if (meta == null || !meta.hasDisplayTitle) {
      result.add(id);
    }
  }
  return result;
}

/// Serializes [meta] for Firestore (or null when empty).
Map<String, dynamic>? youtubeVideoMetaToFirestore(
  Map<String, YoutubeVideoMeta>? meta,
) {
  if (meta == null || meta.isEmpty) return null;
  return {for (final entry in meta.entries) entry.key: entry.value.toMap()};
}

/// Parses `fetchYoutubeVideoMeta` callable [rawData] into videoId → meta.
Map<String, YoutubeVideoMeta> parseFetchYoutubeVideoMetaResponse(
  dynamic rawData,
) {
  if (rawData is! Map) return const {};
  final data = Map<String, dynamic>.from(rawData);
  final rawMetas = data['videos'] ?? data['meta'];
  if (rawMetas == null || rawMetas is! Iterable) return const {};

  final resolved = <String, YoutubeVideoMeta>{};
  for (final item in rawMetas) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final id = map['videoId']?.toString().trim() ?? '';
    if (id.isEmpty) continue;
    final meta = YoutubeVideoMeta.fromMap(map);
    if (!meta.hasDisplayTitle) continue;
    resolved[id] = meta;
  }
  return resolved;
}

/// YouTube thumbnail URL for [videoId]. Import uses `maxresdefault`.
String youtubeThumbnailUrl(String videoId, {String quality = 'maxresdefault'}) {
  return 'https://img.youtube.com/vi/$videoId/$quality.jpg';
}

/// Smaller thumbnail used for edit-screen previews (always present for valid IDs).
String youtubePreviewThumbnailUrl(String videoId) =>
    youtubeThumbnailUrl(videoId, quality: 'hqdefault');

/// Watch URL for a YouTube [videoId].
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';

/// Extracts a video ID from a YouTube CDN thumbnail URL, if present.
String? extractYoutubeVideoIdFromThumbnailUrl(String url) {
  final match = _youtubeThumbnailUrlPattern.firstMatch(url);
  return match?.group(1);
}

/// True when [url] points at a YouTube CDN thumbnail.
bool isYoutubeCdnThumbnailUrl(String url) =>
    extractYoutubeVideoIdFromThumbnailUrl(url) != null;

/// Candidate thumbnail URLs for [url], highest quality first.
/// Returns an empty list when [url] is not a YouTube CDN thumbnail.
List<String> getYoutubeThumbnailUrlCandidates(String url) {
  final videoId = extractYoutubeVideoIdFromThumbnailUrl(url);
  if (videoId == null) return const [];
  return youtubeThumbnailQualities
      .map((quality) => youtubeThumbnailUrl(videoId, quality: quality))
      .toList(growable: false);
}

/// HEAD-checks whether a YouTube thumbnail URL is available (HTTP 200).
Future<bool> checkYoutubeThumbnailAvailable(
  String url, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  final shouldCloseClient = client == null;
  try {
    final response = await httpClient.head(Uri.parse(url));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    if (shouldCloseClient) {
      httpClient.close();
    }
  }
}

/// Returns the highest-quality available YouTube thumbnail URL for [videoId],
/// or null when none are available.
Future<String?> resolveYoutubeThumbnailUrl(
  String videoId, {
  http.Client? client,
}) async {
  final id = videoId.trim();
  if (id.isEmpty) return null;
  final httpClient = client ?? http.Client();
  final shouldCloseClient = client == null;
  try {
    for (final quality in youtubeThumbnailQualities) {
      final url = youtubeThumbnailUrl(id, quality: quality);
      if (await checkYoutubeThumbnailAvailable(url, client: httpClient)) {
        return url;
      }
    }
    return null;
  } finally {
    if (shouldCloseClient) {
      httpClient.close();
    }
  }
}

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

/// Appends Storage-hosted thumbnail URLs for [videoIds].
///
/// Only IDs present in [resolvedUrls] with a non-empty URL are appended.
/// IDs without a resolved Storage URL are skipped (no YouTube CDN fallback).
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
    if (resolved == null || resolved.isEmpty) continue;
    result.add(resolved);
  }
  return result;
}

/// Parses `fetchYoutubeThumbnails` callable [rawData] into videoId -> Storage URL.
///
/// Tolerates dart2wasm JS-interop shapes: outer/nested values may be [Map] but
/// not `Map<String, dynamic>`, and `thumbnails` may be [Iterable] but not [List].
Map<String, String> parseFetchYoutubeThumbnailsResponse(dynamic rawData) {
  if (rawData is! Map) return const {};
  final data = Map<String, dynamic>.from(rawData);
  final rawThumbnails = data['thumbnails'];
  if (rawThumbnails == null || rawThumbnails is! Iterable) return const {};

  final resolved = <String, String>{};
  for (final item in rawThumbnails) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final id = map['videoId']?.toString();
    final url = map['url']?.toString();
    if (id != null && id.isNotEmpty && url != null && url.isNotEmpty) {
      resolved[id] = url;
    }
  }
  return resolved;
}
