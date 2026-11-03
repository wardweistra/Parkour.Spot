import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/community_activity.dart';

/// Explore "Community" stream: region-scoped activity served by the
/// `getCommunityActivityInBounds` callable (backed by the geo-indexed
/// `communityActivity` collection plus `eventMapPins`).
class CommunityActivityService extends ChangeNotifier {
  CommunityActivityService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static const int pastPageSize = 10;

  /// First past page matches [pastPageSize] so the stream opens with a full
  /// page of history around "now", not a short preview.
  static const int pastInitialLimit = pastPageSize;
  static const int upcomingPageSize = 10;

  String? _error;
  String? get error => _error;

  Future<CommunityActivityFeed> getCommunityActivityInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int pastLimit = pastInitialLimit,
    int upcomingPageSize = CommunityActivityService.upcomingPageSize,
    bool includeCounts = true,
    bool fetchPast = true,
    bool fetchUpcoming = true,
    CommunityActivityCursor? pastCursor,
    CommunityActivityCursor? upcomingCursor,
    CommunityActivityCursor? eventCursor,
  }) async {
    final callable = _functions.httpsCallable('getCommunityActivityInBounds');
    final payload = <String, dynamic>{
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
      'pastLimit': pastLimit,
      'upcomingPageSize': upcomingPageSize,
      'includeCounts': includeCounts,
      'fetchPast': fetchPast,
      'fetchUpcoming': fetchUpcoming,
    };
    if (pastCursor != null) {
      payload['pastCursor'] = pastCursor.toCallableMap();
    }
    if (upcomingCursor != null) {
      payload['upcomingCursor'] = upcomingCursor.toCallableMap();
    }
    if (eventCursor != null) {
      payload['eventCursor'] = eventCursor.toCallableMap();
    }

    final result = await callable.call(payload);

    final raw = result.data;
    final responseData = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (responseData == null || responseData['success'] != true) {
      throw Exception(
        responseData != null && responseData['error'] is String
            ? responseData['error']
            : 'Unknown error loading community activity',
      );
    }
    return CommunityActivityFeed.fromCallableMap(responseData);
  }

  /// Older past activity after [feed.pastCursor] for the same bounds.
  Future<CommunityActivityFeed> loadMorePast(
    CommunityActivityFeed feed,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    final cursor = feed.pastCursor;
    if (!feed.hasMorePast || cursor == null) {
      return Future.value(const CommunityActivityFeed());
    }
    return getCommunityActivityInBounds(
      minLat,
      maxLat,
      minLng,
      maxLng,
      pastLimit: pastPageSize,
      includeCounts: false,
      fetchPast: true,
      fetchUpcoming: false,
      pastCursor: cursor,
    );
  }

  /// Further upcoming plans/events after the feed cursors for the same bounds.
  Future<CommunityActivityFeed> loadMoreUpcoming(
    CommunityActivityFeed feed,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    if (!feed.hasMoreUpcoming) {
      return Future.value(const CommunityActivityFeed());
    }
    return getCommunityActivityInBounds(
      minLat,
      maxLat,
      minLng,
      maxLng,
      upcomingPageSize: upcomingPageSize,
      includeCounts: false,
      fetchPast: false,
      fetchUpcoming: true,
      upcomingCursor: feed.upcomingCursor,
      eventCursor: feed.eventCursor,
    );
  }

  /// Rebuilds `communityActivity` from source collections (admin callable).
  Future<Map<String, dynamic>?> backfillCommunityActivity({
    bool purge = false,
  }) async {
    _error = null;
    try {
      final callable = _functions.httpsCallable(
        'backfillCommunityActivity',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call({'purge': purge});
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e, st) {
      _error = 'Failed to backfill community activity: $e';
      debugPrint(
        'CommunityActivityService.backfillCommunityActivity error: $e\n$st',
      );
      notifyListeners();
      return null;
    }
  }
}
