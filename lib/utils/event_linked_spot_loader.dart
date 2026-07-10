import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/spot.dart';
import '../models/spot_list.dart';
import 'event_locate_utils.dart';
import 'event_location_utils.dart';

/// Whether a spot list expands into event map pins (mirrors Cloud Functions).
bool isSpotListExpandableForEventPins(SpotList list) {
  return list.visibility == SpotListVisibility.public ||
      list.visibility == SpotListVisibility.unlisted;
}

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

/// All eligible linked spots for event map display (same walk order as locate).
///
/// Walks [spotIds], then expandable [spotListIds] (`public` / `unlisted` only).
/// Skips hidden / duplicate spots and spots without valid coordinates.
Future<List<Spot>> loadEligibleSpotsForEventPins({
  required FirebaseFirestore firestore,
  required List<String> spotIds,
  required List<String> spotListIds,
}) async {
  final seen = <String>{};
  final result = <Spot>[];

  void addSpot(Spot? spot) {
    if (spot == null || !isSpotEligibleForEventMapPin(spot)) return;
    final id = spot.id?.trim();
    if (id == null || id.isEmpty || seen.contains(id)) return;
    seen.add(id);
    result.add(spot);
  }

  for (final spotId in spotIds) {
    final trimmedId = spotId.trim();
    if (trimmedId.isEmpty) continue;
    addSpot(await _loadSpotById(firestore, trimmedId));
  }

  for (final listId in spotListIds) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) continue;
    final listDoc =
        await firestore.collection('spotLists').doc(trimmedListId).get();
    if (!listDoc.exists || listDoc.data() == null) continue;
    final list = SpotList.fromFirestore(listDoc);
    if (!isSpotListExpandableForEventPins(list)) continue;
    for (final spotId in list.effectiveSpotIds) {
      addSpot(await _loadSpotById(firestore, spotId));
    }
  }

  return result;
}

/// First eligible linked spot for Explore locate when the event has no venue.
///
/// Walks [spotIds], then expandable [spotListIds] (`public` / `unlisted` only).
/// Skips hidden / duplicate spots and spots without valid coordinates.
Future<Spot?> loadFirstEligibleSpotForEventPin({
  required FirebaseFirestore firestore,
  required List<String> spotIds,
  required List<String> spotListIds,
}) async {
  for (final spotId in spotIds) {
    final trimmedId = spotId.trim();
    if (trimmedId.isEmpty) continue;
    final spot = await _loadSpotById(firestore, trimmedId);
    if (spot != null && isSpotEligibleForEventMapPin(spot)) return spot;
  }

  for (final listId in spotListIds) {
    final trimmedListId = listId.trim();
    if (trimmedListId.isEmpty) continue;
    final listDoc =
        await firestore.collection('spotLists').doc(trimmedListId).get();
    if (!listDoc.exists || listDoc.data() == null) continue;
    final list = SpotList.fromFirestore(listDoc);
    if (!isSpotListExpandableForEventPins(list)) continue;
    for (final spotId in list.effectiveSpotIds) {
      final spot = await _loadSpotById(firestore, spotId);
      if (spot != null && isSpotEligibleForEventMapPin(spot)) return spot;
    }
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
