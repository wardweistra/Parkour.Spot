import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parkour_event.dart';

/// Builds Firestore field updates to apply to [original] when merging data from
/// [duplicate] during mark-as-duplicate. Returns an empty map when nothing changes.
Map<String, dynamic> buildEventDuplicateMergeUpdates({
  required ParkourEvent original,
  required ParkourEvent duplicate,
  bool transferPhotos = false,
  bool transferLinkedSpots = false,
  bool overwriteTitle = false,
  bool overwriteDescription = false,
  bool overwriteLocation = false,
  bool overwriteSchedule = false,
  bool overwriteWebsite = false,
}) {
  final updates = <String, dynamic>{};

  if (transferPhotos && duplicate.imageUrls.isNotEmpty) {
    final existingPhotos = List<String>.from(original.imageUrls);
    final newPhotos = duplicate.imageUrls
        .where((url) => !existingPhotos.contains(url))
        .toList();
    if (newPhotos.isNotEmpty) {
      updates['imageUrls'] = [...existingPhotos, ...newPhotos];
    }
  }

  if (transferLinkedSpots) {
    if (duplicate.spotIds.isNotEmpty) {
      final existing = List<String>.from(original.spotIds);
      final added = duplicate.spotIds
          .where((id) => !existing.contains(id))
          .toList();
      if (added.isNotEmpty) {
        updates['spotIds'] = [...existing, ...added];
      }
    }
    if (duplicate.spotListIds.isNotEmpty) {
      final existing = List<String>.from(original.spotListIds);
      final added = duplicate.spotListIds
          .where((id) => !existing.contains(id))
          .toList();
      if (added.isNotEmpty) {
        updates['spotListIds'] = [...existing, ...added];
      }
    }
  }

  if (overwriteTitle && duplicate.title.trim().isNotEmpty) {
    updates['title'] = duplicate.title;
  }

  if (overwriteDescription) {
    final description = duplicate.description?.trim();
    if (description != null && description.isNotEmpty) {
      updates['description'] = duplicate.description;
    }
  }

  if (overwriteLocation) {
    if (duplicate.latitude != null &&
        duplicate.longitude != null &&
        (duplicate.latitude != 0.0 || duplicate.longitude != 0.0)) {
      updates['latitude'] = duplicate.latitude;
      updates['longitude'] = duplicate.longitude;
    }
    if (duplicate.address != null && duplicate.address!.trim().isNotEmpty) {
      updates['address'] = duplicate.address;
    }
    if (duplicate.city != null && duplicate.city!.trim().isNotEmpty) {
      updates['city'] = duplicate.city;
    }
    if (duplicate.countryCode != null &&
        duplicate.countryCode!.trim().isNotEmpty) {
      updates['countryCode'] = duplicate.countryCode;
    }
  }

  if (overwriteSchedule) {
    updates['startAt'] = Timestamp.fromDate(duplicate.startAt.toUtc());
    updates['endAt'] = duplicate.endAt != null
        ? Timestamp.fromDate(duplicate.endAt!.toUtc())
        : null;
    updates['isDateOnly'] = duplicate.isDateOnly;
    updates['timeZone'] = duplicate.timeZone;
    updates['timeZoneSource'] = duplicate.timeZoneSource;
  }

  if (overwriteWebsite) {
    final website = duplicate.websiteUrl?.trim();
    if (website != null && website.isNotEmpty) {
      updates['websiteUrl'] = duplicate.websiteUrl;
    }
  }

  return updates;
}

/// Whether [event] has photos that can be transferred to an original.
bool eventHasTransferablePhotos(ParkourEvent event) =>
    event.imageUrls.isNotEmpty;

/// Whether [event] has linked spots/lists that can be transferred.
bool eventHasTransferableLinkedSpots(ParkourEvent event) =>
    event.spotIds.isNotEmpty || event.spotListIds.isNotEmpty;

bool eventHasOverwriteTitle(ParkourEvent event) =>
    event.title.trim().isNotEmpty;

bool eventHasOverwriteDescription(ParkourEvent event) =>
    event.description != null && event.description!.trim().isNotEmpty;

bool eventHasOverwriteLocation(ParkourEvent event) {
  if (event.latitude != null &&
      event.longitude != null &&
      (event.latitude != 0.0 || event.longitude != 0.0)) {
    return true;
  }
  if (event.address != null && event.address!.trim().isNotEmpty) return true;
  if (event.city != null && event.city!.trim().isNotEmpty) return true;
  if (event.countryCode != null && event.countryCode!.trim().isNotEmpty) {
    return true;
  }
  return false;
}

/// Schedule is always present on events ([ParkourEvent.startAt] is required).
bool eventHasOverwriteSchedule(ParkourEvent _) => true;

bool eventHasOverwriteWebsite(ParkourEvent event) =>
    event.websiteUrl != null && event.websiteUrl!.trim().isNotEmpty;
