import '../models/event_map_pin.dart';
import '../models/parkour_event.dart';

/// Display model for an upcoming event linked to a spot or spot list.
class UpcomingLinkedEvent {
  final String id;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final bool isDateOnly;
  final String? timeZone;

  const UpcomingLinkedEvent({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
    this.isDateOnly = false,
    this.timeZone,
  });

  factory UpcomingLinkedEvent.fromEventMapPin(EventMapPin pin) {
    return UpcomingLinkedEvent(
      id: pin.eventId,
      title: pin.title,
      startAt: pin.startAt,
      endAt: pin.endAt,
      isDateOnly: pin.isDateOnly,
      timeZone: pin.timeZone,
    );
  }

  factory UpcomingLinkedEvent.fromParkourEvent(ParkourEvent event) {
    final id = event.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('ParkourEvent.id is required');
    }
    return UpcomingLinkedEvent(
      id: id,
      title: event.title,
      startAt: event.startAt,
      endAt: event.endAt,
      isDateOnly: event.isDateOnly,
      timeZone: event.timeZone,
    );
  }
}

/// Spot-kind pins for [spotId], deduped by [EventMapPin.eventId], earliest first.
///
/// When multiple pins share an [eventId], keeps the earliest [startAt].
List<EventMapPin> dedupeAndSortSpotEventPins(
  Iterable<EventMapPin> pins, {
  String? spotId,
}) {
  final byEventId = <String, EventMapPin>{};
  for (final pin in pins) {
    if (pin.kind != EventMapPinKind.spot) continue;
    if (spotId != null && pin.spotId != spotId) continue;
    final eventId = pin.eventId.trim();
    if (eventId.isEmpty) continue;
    final existing = byEventId[eventId];
    if (existing == null || pin.startAt.isBefore(existing.startAt)) {
      byEventId[eventId] = pin;
    }
  }
  final sorted = byEventId.values.toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return sorted;
}

/// Maps pins to [UpcomingLinkedEvent], preserving order.
List<UpcomingLinkedEvent> upcomingLinkedEventsFromPins(
  Iterable<EventMapPin> pins,
) {
  return pins.map(UpcomingLinkedEvent.fromEventMapPin).toList(growable: false);
}

/// Maps events to [UpcomingLinkedEvent], skipping events without an id.
List<UpcomingLinkedEvent> upcomingLinkedEventsFromParkourEvents(
  Iterable<ParkourEvent> events,
) {
  final result = <UpcomingLinkedEvent>[];
  for (final event in events) {
    final id = event.id;
    if (id == null || id.isEmpty) continue;
    result.add(UpcomingLinkedEvent.fromParkourEvent(event));
  }
  return result;
}
