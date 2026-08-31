/// Query param carrying the inbox document id on push click-through URLs.
const String kInboxNotificationIdQueryParam = 'nid';

/// Inbox document id from a push click URL, or null if absent/blank.
String? notificationIdFromUri(Uri uri) {
  final raw = uri.queryParameters[kInboxNotificationIdQueryParam];
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Same URI without [kInboxNotificationIdQueryParam]; other query params kept.
Uri uriWithoutNotificationId(Uri uri) {
  if (!uri.queryParameters.containsKey(kInboxNotificationIdQueryParam)) {
    return uri;
  }
  final params = Map<String, String>.from(uri.queryParameters)
    ..remove(kInboxNotificationIdQueryParam);
  if (params.isEmpty) {
    return uri.replace(query: '');
  }
  return uri.replace(queryParameters: params);
}

/// Path + query for [GoRouter] ([go] / [replace]), without scheme or host.
String goLocationFromUri(Uri uri) {
  final stripped = uriWithoutNotificationId(uri);
  final path = stripped.path.isEmpty ? '/' : stripped.path;
  final query = stripped.query;
  if (query.isEmpty) return path;
  return '$path?$query';
}
