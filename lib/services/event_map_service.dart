import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/event_map_pin.dart';
import '../models/parkour_event.dart';
import '../utils/event_linked_spot_loader.dart';
import '../utils/event_locate_utils.dart';

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
  EventMapService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

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

  /// Materialized map pins for a single event (venue and/or linked spots).
  Future<List<EventMapPin>> getMapPinsForEvent(String eventId) async {
    final trimmed = eventId.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final snapshot = await _firestore
          .collection('eventMapPins')
          .where('eventId', isEqualTo: trimmed)
          .get();
      return snapshot.docs.map(EventMapPin.fromFirestore).toList();
    } catch (e, st) {
      debugPrint('EventMapService.getMapPinsForEvent error: $e\n$st');
      return const [];
    }
  }

  /// Resolves a pin for Explore locate (direct coords, map pins, or linked spots).
  Future<EventMapPin?> resolvePinForLocate(ParkourEvent event) async {
    final target = await resolveLocateTargetForEvent(event);
    return target?.pin;
  }

  /// Resolves spot list vs single-pin locate for an event.
  Future<EventLocateTarget?> resolveLocateTargetForEvent(
    ParkourEvent event,
  ) {
    return resolveEventLocateTarget(
      event: event,
      firestore: _firestore,
      getMapPinsForEvent: getMapPinsForEvent,
      loadEligibleLinkedSpot:
          ({required List<String> spotIds, required List<String> spotListIds}) {
            return loadFirstEligibleSpotForEventPin(
              firestore: _firestore,
              spotIds: spotIds,
              spotListIds: spotListIds,
            );
          },
    );
  }
}
