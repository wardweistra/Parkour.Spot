import '../models/event_interest.dart';
import '../models/parkour_event.dart';

/// Tapping the already-selected status clears it; otherwise it becomes [tapped].
EventInterestStatus? nextEventInterestStatus(
  EventInterestStatus? current,
  EventInterestStatus tapped,
) {
  if (current == tapped) return null;
  return tapped;
}

EventInterestStats eventInterestStatsAfterChange({
  required EventInterestStats stats,
  EventInterestStatus? from,
  EventInterestStatus? to,
}) {
  if (from == to) return stats;
  var going = stats.goingCount;
  var interested = stats.interestedCount;
  if (from == EventInterestStatus.going) going -= 1;
  if (from == EventInterestStatus.interested) interested -= 1;
  if (to == EventInterestStatus.going) going += 1;
  if (to == EventInterestStatus.interested) interested += 1;
  return EventInterestStats(
    goingCount: going < 0 ? 0 : going,
    interestedCount: interested < 0 ? 0 : interested,
  );
}

/// Whether the event has already ended (missing [ParkourEvent.endAt] uses start).
bool isParkourEventPast(ParkourEvent event, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final end = (event.endAt ?? event.startAt).toUtc();
  return end.isBefore(reference);
}

class MyEventEntry {
  const MyEventEntry({required this.interest, required this.event});

  final EventInterest interest;
  final ParkourEvent event;
}

class MyEventsPartition {
  const MyEventsPartition({required this.upcoming, required this.past});

  final List<MyEventEntry> upcoming;
  final List<MyEventEntry> past;
}

/// Joins interests to events and splits upcoming vs past (hidden events kept).
MyEventsPartition partitionMyEvents(
  Iterable<EventInterest> interests,
  Map<String, ParkourEvent> eventsById, {
  DateTime? now,
}) {
  final entries = <MyEventEntry>[];
  for (final interest in interests) {
    final event = eventsById[interest.eventId];
    if (event == null) continue;
    entries.add(MyEventEntry(interest: interest, event: event));
  }

  final upcoming = <MyEventEntry>[];
  final past = <MyEventEntry>[];
  for (final entry in entries) {
    if (isParkourEventPast(entry.event, now: now)) {
      past.add(entry);
    } else {
      upcoming.add(entry);
    }
  }

  upcoming.sort((a, b) {
    final startCmp = a.event.startAt.compareTo(b.event.startAt);
    if (startCmp != 0) return startCmp;
    return a.event.title.toLowerCase().compareTo(b.event.title.toLowerCase());
  });
  past.sort((a, b) {
    final startCmp = b.event.startAt.compareTo(a.event.startAt);
    if (startCmp != 0) return startCmp;
    return a.event.title.toLowerCase().compareTo(b.event.title.toLowerCase());
  });

  return MyEventsPartition(upcoming: upcoming, past: past);
}
