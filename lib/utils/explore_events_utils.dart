import '../models/event_map_pin.dart';

/// Earliest [EventMapPin] per [spotId] for spot-card badges.
Map<String, EventMapPin> eventPinsBySpotId(Iterable<EventMapPin> pins) {
  final result = <String, EventMapPin>{};
  for (final pin in pins) {
    if (pin.kind != EventMapPinKind.spot) continue;
    final spotId = pin.spotId;
    if (spotId == null || spotId.isEmpty) continue;
    final existing = result[spotId];
    if (existing == null || pin.startAt.isBefore(existing.startAt)) {
      result[spotId] = pin;
    }
  }
  return result;
}

/// One representative pin per [eventId] (earliest [startAt]).
List<EventMapPin> dedupePinsByEventId(List<EventMapPin> pins) {
  final byEvent = <String, EventMapPin>{};
  for (final pin in pins) {
    final existing = byEvent[pin.eventId];
    if (existing == null || pin.startAt.isBefore(existing.startAt)) {
      byEvent[pin.eventId] = pin;
    }
  }
  final result = byEvent.values.toList();
  result.sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}
