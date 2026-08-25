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

Duration eventDatetimeStartDelta(
  ParkourEvent event, {
  required DateTime referenceStartAt,
}) {
  return event.startAt.difference(referenceStartAt).abs();
}

Duration eventDatetimeEndDelta(
  ParkourEvent event, {
  required DateTime referenceStartAt,
  DateTime? referenceEndAt,
}) {
  final eventEnd = event.endAt ?? event.startAt;
  final referenceEnd = referenceEndAt ?? referenceStartAt;
  return eventEnd.difference(referenceEnd).abs();
}

/// Orders candidates by how close their datetimes are to the reference event.
///
/// Closer [ParkourEvent.startAt] wins first, then closer end (missing end is
/// treated as start). Equal times prefer native events so a selectable original
/// surfaces before an external copy.
int compareEventsByDatetimeProximity(
  ParkourEvent a,
  ParkourEvent b, {
  required DateTime referenceStartAt,
  DateTime? referenceEndAt,
}) {
  final startCmp = eventDatetimeStartDelta(
    a,
    referenceStartAt: referenceStartAt,
  ).compareTo(eventDatetimeStartDelta(b, referenceStartAt: referenceStartAt));
  if (startCmp != 0) return startCmp;

  final endCmp =
      eventDatetimeEndDelta(
        a,
        referenceStartAt: referenceStartAt,
        referenceEndAt: referenceEndAt,
      ).compareTo(
        eventDatetimeEndDelta(
          b,
          referenceStartAt: referenceStartAt,
          referenceEndAt: referenceEndAt,
        ),
      );
  if (endCmp != 0) return endCmp;

  if (a.isNativeEvent != b.isNativeEvent) {
    return a.isNativeEvent ? -1 : 1;
  }
  return 0;
}

void sortEventsByDatetimeProximity(
  List<ParkourEvent> events, {
  required DateTime referenceStartAt,
  DateTime? referenceEndAt,
}) {
  events.sort(
    (a, b) => compareEventsByDatetimeProximity(
      a,
      b,
      referenceStartAt: referenceStartAt,
      referenceEndAt: referenceEndAt,
    ),
  );
}

/// Normalizes an ISO country code for duplicate-picker comparisons.
String? normalizedEventCountryCode(String? countryCode) {
  final normalized = countryCode?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

/// Whether [candidate] should stay in duplicate suggestions for [referenceCountryCode].
///
/// When either side has no country code, the candidate is kept. Otherwise only
/// matching countries are kept.
bool isEventInDuplicateCountry(
  ParkourEvent candidate, {
  required String? referenceCountryCode,
}) {
  final reference = normalizedEventCountryCode(referenceCountryCode);
  if (reference == null) return true;

  final candidateCountry = normalizedEventCountryCode(candidate.countryCode);
  if (candidateCountry == null) return true;

  return candidateCountry == reference;
}

List<ParkourEvent> filterEventsByDuplicateCountry(
  Iterable<ParkourEvent> events, {
  required String? referenceCountryCode,
}) {
  return events
      .where(
        (event) => isEventInDuplicateCountry(
          event,
          referenceCountryCode: referenceCountryCode,
        ),
      )
      .toList(growable: false);
}
