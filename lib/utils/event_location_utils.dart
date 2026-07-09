import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/spot.dart';

bool spotHasCoordinates(Spot spot) =>
    spot.latitude != 0 || spot.longitude != 0;

/// Whether the event has its own location (map pin or address), not just linked spots.
bool eventHasDirectLocation({
  double? latitude,
  double? longitude,
  String? address,
}) {
  final hasCoordinates = latitude != null && longitude != null;
  final hasAddress = address?.trim().isNotEmpty == true;
  return hasCoordinates || hasAddress;
}

/// First linked spot used to infer city/country when the event has no direct location.
Spot? pickSourceSpotForCityCountry({
  required List<Spot> linkedSpots,
  required List<Spot> linkedSpotListSpots,
}) {
  if (linkedSpots.isNotEmpty) return linkedSpots.first;
  if (linkedSpotListSpots.isNotEmpty) return linkedSpotListSpots.first;
  return null;
}

/// Fills missing city/country from [sourceSpot] without overwriting existing values.
({String? city, String? countryCode}) resolveCityCountryFromSourceSpot({
  String? city,
  String? countryCode,
  Spot? sourceSpot,
}) {
  final normalizedCity = city?.trim();
  final normalizedCountryCode = countryCode?.trim().toUpperCase();
  final hasCity = normalizedCity != null && normalizedCity.isNotEmpty;
  final hasCountryCode =
      normalizedCountryCode != null && normalizedCountryCode.isNotEmpty;

  final spotCity = sourceSpot?.city?.trim();
  final spotCountryCode = sourceSpot?.countryCode?.trim().toUpperCase();

  return (
    city: hasCity
        ? normalizedCity
        : (spotCity != null && spotCity.isNotEmpty ? spotCity : null),
    countryCode: hasCountryCode
        ? normalizedCountryCode
        : (spotCountryCode != null && spotCountryCode.isNotEmpty
              ? spotCountryCode
              : null),
  );
}

/// Resolves event city/country, inheriting from linked spots when there is no direct location.
({String? city, String? countryCode}) resolveEventCityCountryFromLinkedSpots({
  required double? latitude,
  required double? longitude,
  required String? address,
  String? city,
  String? countryCode,
  required List<Spot> linkedSpots,
  required List<Spot> linkedSpotListSpots,
}) {
  final trimmedCity = city?.trim();
  final trimmedCountryCode = countryCode?.trim().toUpperCase();

  if (eventHasDirectLocation(
    latitude: latitude,
    longitude: longitude,
    address: address,
  )) {
    return (
      city: trimmedCity?.isNotEmpty == true ? trimmedCity : null,
      countryCode: trimmedCountryCode?.isNotEmpty == true
          ? trimmedCountryCode
          : null,
    );
  }

  final sourceSpot = pickSourceSpotForCityCountry(
    linkedSpots: linkedSpots,
    linkedSpotListSpots: linkedSpotListSpots,
  );
  return resolveCityCountryFromSourceSpot(
    city: city,
    countryCode: countryCode,
    sourceSpot: sourceSpot,
  );
}

/// Resolves coordinates used to infer an event's timezone.
///
/// Priority: explicit map pin, first linked spot, first spot-list spot.
LatLng? resolveEventTimezoneCoordinates({
  LatLng? pickedLocation,
  required List<Spot> linkedSpots,
  required List<Spot> linkedSpotListSpots,
}) {
  if (pickedLocation != null) return pickedLocation;

  for (final spot in linkedSpots) {
    if (spotHasCoordinates(spot)) {
      return LatLng(spot.latitude, spot.longitude);
    }
  }

  for (final spot in linkedSpotListSpots) {
    if (spotHasCoordinates(spot)) {
      return LatLng(spot.latitude, spot.longitude);
    }
  }

  return null;
}
