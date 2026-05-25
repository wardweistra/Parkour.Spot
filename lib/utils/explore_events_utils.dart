import '../models/event_map_pin.dart';
import 'event_schedule_utils.dart';

/// Events in one calendar month (display timezone), for Explore list sectioning.
class ExploreEventsMonthGroup {
  final DateTime monthStart;
  final List<EventMapPin> events;

  const ExploreEventsMonthGroup({
    required this.monthStart,
    required this.events,
  });
}

DateTime _monthStartForPin(EventMapPin pin) {
  final display = EventScheduleUtils.toDisplayDateTime(
    pin.startAt,
    timeZone: pin.timeZone,
  );
  return DateTime(display.year, display.month);
}

/// Groups pre-sorted [events] by display month of [EventMapPin.startAt].
List<ExploreEventsMonthGroup> groupExploreEventsByMonth(
  List<EventMapPin> events,
) {
  if (events.isEmpty) return const [];

  final groups = <ExploreEventsMonthGroup>[];
  DateTime? currentMonth;
  var currentEvents = <EventMapPin>[];

  void flush() {
    final month = currentMonth;
    if (month == null || currentEvents.isEmpty) return;
    groups.add(
      ExploreEventsMonthGroup(
        monthStart: month,
        events: List.unmodifiable(currentEvents),
      ),
    );
  }

  for (final pin in events) {
    final monthStart = _monthStartForPin(pin);
    if (currentMonth == null) {
      currentMonth = monthStart;
      currentEvents = [pin];
      continue;
    }
    if (monthStart == currentMonth) {
      currentEvents.add(pin);
      continue;
    }
    flush();
    currentMonth = monthStart;
    currentEvents = [pin];
  }
  flush();
  return groups;
}

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
