import '../models/parkour_event.dart';

/// Padding around an event's start/end when finding likely duplicate candidates.
const kEventDuplicateDatePadding = Duration(days: 7);

/// Inclusive date range used to filter duplicate-picker suggestions.
class EventDateWindow {
  const EventDateWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory EventDateWindow.aroundEvent({
    required DateTime startAt,
    DateTime? endAt,
    Duration padding = kEventDuplicateDatePadding,
  }) {
    final effectiveEnd = endAt ?? startAt;
    return EventDateWindow(
      start: startAt.subtract(padding),
      end: effectiveEnd.add(padding),
    );
  }

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return !rangeStart.isAfter(end) && !rangeEnd.isBefore(start);
  }

  bool overlapsParkourEvent(ParkourEvent event) {
    final eventEnd = event.endAt ?? event.startAt;
    return overlaps(event.startAt, eventEnd);
  }
}
