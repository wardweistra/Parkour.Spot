import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Callable wrapper for the per-user secret iCal subscription feed.
class UserCalendarFeedService {
  UserCalendarFeedService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static const String defaultCalendarDisplayName = 'ParkourSpot My events';

  /// Returns the subscribe URL, creating a feed token if needed.
  Future<String> getOrCreateFeedUrl() async {
    final callable = _functions.httpsCallable('getOrCreateMyCalendarFeed');
    final result = await callable.call(<String, dynamic>{});
    return _urlFromResult(result.data, 'getOrCreateMyCalendarFeed');
  }

  /// Rotates the feed token and returns the new subscribe URL.
  Future<String> regenerateFeedUrl() async {
    final callable = _functions.httpsCallable('regenerateMyCalendarFeed');
    final result = await callable.call(<String, dynamic>{});
    return _urlFromResult(result.data, 'regenerateMyCalendarFeed');
  }

  /// Apple Calendar-style subscribe URL (`webcal://…`).
  static String toWebcalUrl(String httpsUrl) {
    final uri = Uri.tryParse(httpsUrl.trim());
    if (uri == null) return httpsUrl;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return uri.replace(scheme: 'webcal').toString();
    }
    return httpsUrl;
  }

  /// Google Calendar “add by URL” deep link for an https ICS feed.
  ///
  /// Google’s `cid=` handoff often rejects bare `https://` feed URLs with
  /// “Unable to import calendar” even when Settings → From URL accepts the
  /// same https link. Passing `webcal://` in `cid` is the reliable form.
  static String toGoogleCalendarSubscribeUrl(String httpsIcsUrl) {
    final webcal = toWebcalUrl(httpsIcsUrl);
    return Uri.https('www.google.com', '/calendar/render', {
      'cid': webcal,
    }).toString();
  }

  /// Outlook.com “add calendar from web” deep link for an https ICS feed.
  static String toOutlookCalendarSubscribeUrl(
    String httpsIcsUrl, {
    String name = defaultCalendarDisplayName,
  }) {
    final feed = httpsIcsUrl.trim();
    return Uri.https('outlook.live.com', '/calendar/0/addfromweb', {
      'url': feed,
      'name': name,
    }).toString();
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
    debugPrint('UserCalendarFeedService error: $error');
    return error.toString();
  }
}
