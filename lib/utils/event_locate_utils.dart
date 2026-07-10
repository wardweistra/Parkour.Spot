import '../models/event_map_pin.dart';
import '../models/parkour_event.dart';
import '../models/spot.dart';
import 'event_location_utils.dart';
import 'explore_events_utils.dart';

/// Whether [spot] can be used as an event map pin (mirrors Cloud Functions).
bool isSpotEligibleForEventMapPin(Spot spot) {
  if (spot.hidden) return false;
  final duplicateOf = spot.duplicateOf?.trim();
  if (duplicateOf != null && duplicateOf.isNotEmpty) return false;
  if (!spotHasCoordinates(spot)) return false;
  if (spot.latitude < -90 || spot.latitude > 90) return false;
  if (spot.longitude < -180 || spot.longitude > 180) return false;
  return true;
}

/// Builds a spot-kind pin from a linked [spot] for Explore locate.
EventMapPin eventMapPinFromLinkedSpot({
  required ParkourEvent event,
  required Spot spot,
}) {
  final eventId = event.id;
  if (eventId == null || eventId.isEmpty) {
    throw ArgumentError('ParkourEvent.id is required');
  }
  final spotId = spot.id;
  if (spotId == null || spotId.isEmpty) {
    throw ArgumentError('Spot.id is required');
  }
  if (!isSpotEligibleForEventMapPin(spot)) {
    throw ArgumentError('Spot is not eligible for an event map pin');
  }

  final eventCity = event.city?.trim();
  final eventCountry = event.countryCode?.trim().toUpperCase();
  final spotCity = spot.city?.trim();
  final spotCountry = spot.countryCode?.trim().toUpperCase();

  return EventMapPin(
    id: '${eventId}_spot_$spotId',
    eventId: eventId,
    kind: EventMapPinKind.spot,
    latitude: spot.latitude,
    longitude: spot.longitude,
    title: event.title.trim().isNotEmpty ? event.title.trim() : 'Event',
    startAt: event.startAt,
    endAt: event.endAt,
    isDateOnly: event.isDateOnly,
    timeZone: event.timeZone,
    spotId: spotId,
    description: event.description,
    imageUrls: event.imageUrls,
    city: (eventCity != null && eventCity.isNotEmpty)
        ? eventCity
        : (spotCity != null && spotCity.isNotEmpty ? spotCity : null),
    countryCode: (eventCountry != null && eventCountry.isNotEmpty)
        ? eventCountry
        : (spotCountry != null && spotCountry.isNotEmpty ? spotCountry : null),
  );
}

/// One representative pin for locate (same preference as map list cards).
EventMapPin? pickRepresentativePinForLocate(List<EventMapPin> pins) {
  if (pins.isEmpty) return null;
  final deduped = dedupePinsByEventId(pins);
  return deduped.isEmpty ? null : deduped.first;
}

/// Resolves a map pin for Explore locate.
///
/// Order: direct event coordinates → materialized [eventMapPins] → first
/// eligible linked spot / expandable spot list.
Future<EventMapPin?> resolveEventMapPinForLocate({
  required ParkourEvent event,
  required Future<List<EventMapPin>> Function(String eventId) getMapPinsForEvent,
  required Future<Spot?> Function({
    required List<String> spotIds,
    required List<String> spotListIds,
  })
  loadEligibleLinkedSpot,
}) async {
  final eventId = event.id?.trim();
  if (eventId == null || eventId.isEmpty) return null;

  if (event.latitude != null && event.longitude != null) {
    return EventMapPin.fromParkourEvent(event);
  }

  final pins = await getMapPinsForEvent(eventId);
  final fromPins = pickRepresentativePinForLocate(pins);
  if (fromPins != null) return fromPins;

  final spot = await loadEligibleLinkedSpot(
    spotIds: event.spotIds,
    spotListIds: event.spotListIds,
  );
  if (spot == null || spot.id == null || spot.id!.isEmpty) return null;
  if (!isSpotEligibleForEventMapPin(spot)) return null;

  return eventMapPinFromLinkedSpot(event: event, spot: spot);
}
