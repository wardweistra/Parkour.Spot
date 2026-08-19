import '../models/event_map_pin.dart';
import '../models/parkour_event.dart';

/// Display model for an event linked to a spot or spot list.
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

  bool isPast({DateTime? now}) {
    return isLinkedEventPast(startAt: startAt, endAt: endAt, now: now);
  }

  LinkedEventTiming timing({DateTime? now}) {
    return linkedEventTiming(startAt: startAt, endAt: endAt, now: now);
  }
}

/// Upcoming (including in-progress) and past linked events for a spot or list.
class LinkedSpotEvents {
  const LinkedSpotEvents({this.upcoming = const [], this.past = const []});

  final List<UpcomingLinkedEvent> upcoming;
  final List<UpcomingLinkedEvent> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;

  /// Next upcoming (soonest), or the most recent past when nothing is upcoming.
  UpcomingLinkedEvent? get featured {
    if (upcoming.isNotEmpty) return upcoming.first;
    if (past.isNotEmpty) return past.first;
    return null;
  }

  bool get featuresUpcoming => upcoming.isNotEmpty;
}

/// True when the event has already ended. Uses [endAt] when present, else [startAt].
///
/// Matches Cloud Functions `isEventPast`: an event that has started but not
/// ended is still upcoming.
bool isLinkedEventPast({
  required DateTime startAt,
  DateTime? endAt,
  DateTime? now,
}) {
  final utcNow = (now ?? DateTime.now()).toUtc();
  final effectiveEnd = endAt ?? startAt;
  return effectiveEnd.toUtc().isBefore(utcNow);
}

/// True when [startAt] has been reached and the event has not yet ended.
bool isLinkedEventHappening({
  required DateTime startAt,
  DateTime? endAt,
  DateTime? now,
}) {
  if (isLinkedEventPast(startAt: startAt, endAt: endAt, now: now)) {
    return false;
  }
  final utcNow = (now ?? DateTime.now()).toUtc();
  return !startAt.toUtc().isAfter(utcNow);
}

enum LinkedEventTiming { upcoming, happening, past }

LinkedEventTiming linkedEventTiming({
  required DateTime startAt,
  DateTime? endAt,
  DateTime? now,
}) {
  if (isLinkedEventPast(startAt: startAt, endAt: endAt, now: now)) {
    return LinkedEventTiming.past;
  }
  if (isLinkedEventHappening(startAt: startAt, endAt: endAt, now: now)) {
    return LinkedEventTiming.happening;
  }
  return LinkedEventTiming.upcoming;
}

enum LinkedEventsMoreKind { remaining, pastOnly }

/// Secondary callout action: remaining events, or past-only when the
/// featured event is upcoming and nothing else upcoming remains.
class LinkedEventsMoreAction {
  const LinkedEventsMoreAction({required this.kind, required this.count});

  final LinkedEventsMoreKind kind;
  final int count;
}

LinkedEventsMoreAction? linkedEventsMoreAction(LinkedSpotEvents events) {
  if (events.upcoming.isNotEmpty) {
    final extraUpcoming = events.upcoming.length - 1;
    if (extraUpcoming > 0) {
      return LinkedEventsMoreAction(
        kind: LinkedEventsMoreKind.remaining,
        count: extraUpcoming + events.past.length,
      );
    }
    if (events.past.isNotEmpty) {
      return LinkedEventsMoreAction(
        kind: LinkedEventsMoreKind.pastOnly,
        count: events.past.length,
      );
    }
    return null;
  }
  if (events.past.length > 1) {
    return LinkedEventsMoreAction(
      kind: LinkedEventsMoreKind.remaining,
      count: events.past.length - 1,
    );
  }
  return null;
}

/// All linked events, farthest future first through oldest past.
List<UpcomingLinkedEvent> linkedEventsSheetOrder(LinkedSpotEvents events) {
  return [...events.upcoming, ...events.past]
    ..sort((a, b) => b.startAt.compareTo(a.startAt));
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

/// Splits events into upcoming (earliest first) and past (most recent first).
LinkedSpotEvents partitionLinkedEvents(
  Iterable<UpcomingLinkedEvent> events, {
  DateTime? now,
}) {
  final upcoming = <UpcomingLinkedEvent>[];
  final past = <UpcomingLinkedEvent>[];
  for (final event in events) {
    if (event.isPast(now: now)) {
      past.add(event);
    } else {
      upcoming.add(event);
    }
  }
  upcoming.sort((a, b) => a.startAt.compareTo(b.startAt));
  past.sort((a, b) => b.startAt.compareTo(a.startAt));
  return LinkedSpotEvents(upcoming: upcoming, past: past);
}

/// Unions pin and event sources by id, preferring [fromEvents], then partitions.
LinkedSpotEvents mergeAndPartitionLinkedEvents({
  Iterable<UpcomingLinkedEvent> fromPins = const [],
  Iterable<UpcomingLinkedEvent> fromEvents = const [],
  DateTime? now,
}) {
  final byId = <String, UpcomingLinkedEvent>{};
  for (final event in fromPins) {
    byId[event.id] = event;
  }
  for (final event in fromEvents) {
    byId[event.id] = event;
  }
  return partitionLinkedEvents(byId.values, now: now);
}
