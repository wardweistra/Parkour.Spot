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

bool _preferEventPin(EventMapPin candidate, EventMapPin current) {
  if (candidate.startAt.isBefore(current.startAt)) return true;
  if (candidate.startAt.isAfter(current.startAt)) return false;
  if (candidate.kind == EventMapPinKind.venue &&
      current.kind != EventMapPinKind.venue) {
    return true;
  }
  if (current.kind == EventMapPinKind.venue &&
      candidate.kind != EventMapPinKind.venue) {
    return false;
  }
  return candidate.imageUrls.length > current.imageUrls.length;
}

/// One representative pin per [eventId] (earliest [startAt], venue preferred).
List<EventMapPin> dedupePinsByEventId(List<EventMapPin> pins) {
  final byEvent = <String, EventMapPin>{};
  for (final pin in pins) {
    final existing = byEvent[pin.eventId];
    if (existing == null || _preferEventPin(pin, existing)) {
      byEvent[pin.eventId] = pin;
    }
  }
  final result = byEvent.values.toList();
  result.sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}
