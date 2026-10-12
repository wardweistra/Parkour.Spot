import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Callable wrapper for the per-user secret KML map subscription feed.
class UserMapFeedService {
  UserMapFeedService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Returns the subscribe URL, creating a feed token if needed.
  Future<String> getOrCreateFeedUrl() async {
    final callable = _functions.httpsCallable('getOrCreateMyMapFeed');
    final result = await callable.call(<String, dynamic>{});
    return _urlFromResult(result.data, 'getOrCreateMyMapFeed');
  }

  /// Rotates the feed token and returns the new subscribe URL.
  Future<String> regenerateFeedUrl() async {
    final callable = _functions.httpsCallable('regenerateMyMapFeed');
    final result = await callable.call(<String, dynamic>{});
    return _urlFromResult(result.data, 'regenerateMyMapFeed');
  }

  /// Opens Google My Maps so the user can import the KML URL.
  static String toGoogleMyMapsUrl() {
    return Uri.https('www.google.com', '/maps/d/').toString();
  }

  String _urlFromResult(Object? raw, String op) {
    if (raw is! Map) {
      throw StateError('$op: expected map response');
    }
    final map = Map<String, dynamic>.from(raw);
    final url = map['url'];
    if (url is! String || url.trim().isEmpty) {
      throw StateError('$op: missing url');
    }
    return url.trim();
  }

  /// Maps callable failures to a short user-facing message when possible.
  static String userFacingError(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return error.code;
    }
    debugPrint('UserMapFeedService error: $error');
    return error.toString();
  }
}
