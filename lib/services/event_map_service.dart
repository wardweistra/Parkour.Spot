import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/event_map_pin.dart';

class EventsInBoundsResult {
  final List<EventMapPin> pins;
  final int shownCount;
  final int? totalCount;
  final int eventCount;

  const EventsInBoundsResult({
    required this.pins,
    required this.shownCount,
    this.totalCount,
    required this.eventCount,
  });
}

class EventMapService extends ChangeNotifier {
  Future<EventsInBoundsResult> getEventsInBounds(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int limit = 100,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('getEventsInBounds');
    final result = await callable.call({
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
      'limit': limit,
    });

    final responseData = result.data as Map<String, dynamic>?;
    if (responseData == null || responseData['success'] != true) {
      throw Exception(
        responseData != null && responseData['error'] is String
            ? responseData['error']
            : 'Unknown error loading events',
      );
    }

    final rawPins = responseData['pins'];
    final pins = rawPins is List
        ? rawPins
            .whereType<Map>()
            .map((e) => EventMapPin.fromCallableMap(Map<String, dynamic>.from(e)))
            .toList()
        : <EventMapPin>[];

    return EventsInBoundsResult(
      pins: pins,
      shownCount: (responseData['shownCount'] as num?)?.toInt() ?? pins.length,
      totalCount: (responseData['totalCount'] as num?)?.toInt(),
      eventCount: (responseData['eventCount'] as num?)?.toInt() ?? 0,
    );
  }
}
