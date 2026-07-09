import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/spot.dart';
import '../models/spot_list.dart';
import 'event_location_utils.dart';

/// Loads the first linked spot used to infer an event's city/country.
Future<Spot?> loadSourceSpotForCityCountry({
  required FirebaseFirestore firestore,
  required List<String> spotIds,
  required List<String> spotListIds,
}) async {
  for (final spotId in spotIds) {
    final trimmedId = spotId.trim();
    if (trimmedId.isEmpty) continue;
    final spot = await _loadSpotById(firestore, trimmedId);
    if (spot != null) return spot;
  }

  for (final listId in spotListIds) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) continue;
    final listDoc = await firestore.collection('spotLists').doc(trimmedListId).get();
    if (!listDoc.exists || listDoc.data() == null) continue;
    final list = SpotList.fromFirestore(listDoc);
    final effectiveSpotIds = list.effectiveSpotIds;
    if (effectiveSpotIds.isEmpty) continue;
    final spot = await _loadSpotById(firestore, effectiveSpotIds.first);
    if (spot != null) return spot;
  }

  return null;
}

Future<Spot?> _loadSpotById(FirebaseFirestore firestore, String spotId) async {
  final doc = await firestore.collection('spots').doc(spotId).get();
  if (!doc.exists || doc.data() == null) return null;
  return Spot.fromFirestore(doc);
}

/// Resolves event city/country, fetching linked spots from Firestore when needed.
Future<({String? city, String? countryCode})> resolveEventCityCountryFromFirestore({
  required FirebaseFirestore firestore,
  required double? latitude,
  required double? longitude,
  required String? address,
  String? city,
  String? countryCode,
  required List<String> spotIds,
  required List<String> spotListIds,
}) async {
  if (eventHasDirectLocation(
    latitude: latitude,
    longitude: longitude,
    address: address,
  )) {
    final trimmedCity = city?.trim();
    final trimmedCountryCode = countryCode?.trim().toUpperCase();
    return (
      city: trimmedCity?.isNotEmpty == true ? trimmedCity : null,
      countryCode: trimmedCountryCode?.isNotEmpty == true
          ? trimmedCountryCode
          : null,
    );
  }

  final sourceSpot = await loadSourceSpotForCityCountry(
    firestore: firestore,
    spotIds: spotIds,
    spotListIds: spotListIds,
  );
  return resolveCityCountryFromSourceSpot(
    city: city,
    countryCode: countryCode,
    sourceSpot: sourceSpot,
  );
}
