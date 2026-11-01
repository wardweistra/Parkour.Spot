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

  String? _error;
  String? get error => _error;

  Future<CommunityActivityFeed> getCommunityActivityInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int pastLimit = 30,
    int upcomingLimit = 30,
    int eventLimit = 20,
  }) async {
    final callable = _functions.httpsCallable('getCommunityActivityInBounds');
    final result = await callable.call({
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
      'pastLimit': pastLimit,
      'upcomingLimit': upcomingLimit,
      'eventLimit': eventLimit,
    });

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
