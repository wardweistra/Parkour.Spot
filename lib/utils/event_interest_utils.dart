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

String? _trimmedId(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Listing the user is viewing. RSVPs are stored against this id.
String? eventInterestWriteEventId(ParkourEvent event) => _trimmedId(event.id);

/// Event ID whose Going / Interested totals include this listing.
///
/// Duplicate listings roll up to the native original, matching spot ratings.
String? canonicalEventInterestEventId(ParkourEvent event) {
  return _trimmedId(event.duplicateOf) ?? _trimmedId(event.id);
}

/// Native event plus this listing and any extra duplicate/native ids.
Set<String> eventInterestClusterIds({
  required ParkourEvent event,
  Iterable<String> extraIds = const [],
}) {
  final ids = <String>{};
  void add(String? id) {
    final trimmed = _trimmedId(id);
    if (trimmed != null) ids.add(trimmed);
  }

  add(event.id);
  add(event.duplicateOf);
  for (final id in extraIds) {
    add(id);
  }
  return ids;
}

/// Going wins when the same user marked more than one listing in a cluster.
EventInterestStatus? clusterEventInterestStatus(
  Iterable<EventInterest> interests,
) {
  EventInterestStatus? status;
  for (final interest in interests) {
    if (interest.status == EventInterestStatus.going) {
      return EventInterestStatus.going;
    }
    status = EventInterestStatus.interested;
  }
  return status;
}

/// Docs to delete so each user has at most one RSVP in a duplicate cluster.
///
/// Clearing removes every cluster doc. Setting a status keeps the listing
/// being viewed and deletes the siblings.
Set<String> eventInterestIdsToDelete({
  required String listingEventId,
  required Iterable<String> clusterEventIds,
  required EventInterestStatus? nextStatus,
}) {
  final listingId = listingEventId.trim();
  final cluster = <String>{
    if (listingId.isNotEmpty) listingId,
    ...clusterEventIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
  };
  if (nextStatus == null) return cluster;
  if (listingId.isEmpty) return cluster;
  return cluster.difference({listingId});
}

/// Native ids referenced by [eventsById] that are not already in the map.
Set<String> missingNativeEventIds(Map<String, ParkourEvent> eventsById) {
  final missing = <String>{};
  for (final event in eventsById.values) {
    final nativeId = _trimmedId(event.duplicateOf);
    if (nativeId != null && !eventsById.containsKey(nativeId)) {
      missing.add(nativeId);
    }
  }
  return missing;
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

MyEventEntry? _remapMyEventEntry(
  EventInterest interest,
  Map<String, ParkourEvent> eventsById,
) {
  final listing = eventsById[interest.eventId];
  if (listing == null) return null;
  final nativeId = _trimmedId(listing.duplicateOf);
  final display = nativeId != null
      ? (eventsById[nativeId] ?? listing)
      : listing;
  return MyEventEntry(interest: interest, event: display);
}

bool _goingWinsOver(
  EventInterestStatus existing,
  EventInterestStatus incoming,
) {
  if (existing == EventInterestStatus.going) return false;
  return incoming == EventInterestStatus.going;
}

/// Joins interests to events, remaps duplicates to the native listing, and
/// splits upcoming vs past (hidden events kept). The same person is shown
/// once per native event; Going wins if they marked both listings.
MyEventsPartition partitionMyEvents(
  Iterable<EventInterest> interests,
  Map<String, ParkourEvent> eventsById, {
  DateTime? now,
}) {
  final byCanonical = <String, MyEventEntry>{};
  for (final interest in interests) {
    final remapped = _remapMyEventEntry(interest, eventsById);
    if (remapped == null) continue;
    final canonicalId =
        _trimmedId(remapped.event.id) ?? remapped.interest.eventId;
    final existing = byCanonical[canonicalId];
    if (existing == null ||
        _goingWinsOver(existing.interest.status, remapped.interest.status)) {
      byCanonical[canonicalId] = remapped;
    }
  }
  final entries = byCanonical.values.toList(growable: false);

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
