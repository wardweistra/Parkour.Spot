import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';

/// Transferable field groups used when reviewing post-link duplicate changes.
enum EventDuplicateFieldGroup {
  photos,
  linkedSpots,
  title,
  description,
  location,
  schedule,
  website,
}

extension EventDuplicateFieldGroupX on EventDuplicateFieldGroup {
  String get firestoreValue {
    switch (this) {
      case EventDuplicateFieldGroup.photos:
        return 'photos';
      case EventDuplicateFieldGroup.linkedSpots:
        return 'linkedSpots';
      case EventDuplicateFieldGroup.title:
        return 'title';
      case EventDuplicateFieldGroup.description:
        return 'description';
      case EventDuplicateFieldGroup.location:
        return 'location';
      case EventDuplicateFieldGroup.schedule:
        return 'schedule';
      case EventDuplicateFieldGroup.website:
        return 'website';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case EventDuplicateFieldGroup.photos:
        return l10n.eventDetailMarkDuplicatePhotos;
      case EventDuplicateFieldGroup.linkedSpots:
        return l10n.eventDetailMarkDuplicateLinkedSpots;
      case EventDuplicateFieldGroup.title:
        return l10n.eventDetailMarkDuplicateEventTitle;
      case EventDuplicateFieldGroup.description:
        return l10n.eventDetailMarkDuplicateDescription;
      case EventDuplicateFieldGroup.location:
        return l10n.eventDetailMarkDuplicateLocation;
      case EventDuplicateFieldGroup.schedule:
        return l10n.eventDetailMarkDuplicateSchedule;
      case EventDuplicateFieldGroup.website:
        return l10n.eventDetailMarkDuplicateWebsite;
    }
  }
}

EventDuplicateFieldGroup? eventDuplicateFieldGroupFromString(String value) {
  switch (value.trim()) {
    case 'photos':
      return EventDuplicateFieldGroup.photos;
    case 'linkedSpots':
      return EventDuplicateFieldGroup.linkedSpots;
    case 'title':
      return EventDuplicateFieldGroup.title;
    case 'description':
      return EventDuplicateFieldGroup.description;
    case 'location':
      return EventDuplicateFieldGroup.location;
    case 'schedule':
      return EventDuplicateFieldGroup.schedule;
    case 'website':
      return EventDuplicateFieldGroup.website;
    default:
      return null;
  }
}

List<EventDuplicateFieldGroup> parseDuplicateChangedFieldGroups(
  Iterable<String> values,
) {
  final result = <EventDuplicateFieldGroup>[];
  final seen = <EventDuplicateFieldGroup>{};
  for (final value in values) {
    final group = eventDuplicateFieldGroupFromString(value);
    if (group == null || seen.contains(group)) continue;
    seen.add(group);
    result.add(group);
  }
  return result;
}

bool _nullableStringsEqual(String? left, String? right) {
  final normalizedLeft = left?.trim();
  final normalizedRight = right?.trim();
  final leftValue = (normalizedLeft == null || normalizedLeft.isEmpty)
      ? null
      : normalizedLeft;
  final rightValue = (normalizedRight == null || normalizedRight.isEmpty)
      ? null
      : normalizedRight;
  return leftValue == rightValue;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _stringSetsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  final sortedLeft = [...left]..sort();
  final sortedRight = [...right]..sort();
  return _stringListsEqual(sortedLeft, sortedRight);
}

/// Field groups that differ between [previous] (baseline) and [current].
List<EventDuplicateFieldGroup> changedEventDuplicateFieldGroups({
  required ParkourEvent previous,
  required ParkourEvent current,
}) {
  final changed = <EventDuplicateFieldGroup>[];
  if (!_stringListsEqual(previous.imageUrls, current.imageUrls)) {
    changed.add(EventDuplicateFieldGroup.photos);
  }
  if (!_stringSetsEqual(previous.spotIds, current.spotIds) ||
      !_stringSetsEqual(previous.spotListIds, current.spotListIds)) {
    changed.add(EventDuplicateFieldGroup.linkedSpots);
  }
  if (!_nullableStringsEqual(previous.title, current.title)) {
    changed.add(EventDuplicateFieldGroup.title);
  }
  if (!_nullableStringsEqual(previous.description, current.description)) {
    changed.add(EventDuplicateFieldGroup.description);
  }
  if (previous.latitude != current.latitude ||
      previous.longitude != current.longitude ||
      !_nullableStringsEqual(previous.address, current.address) ||
      !_nullableStringsEqual(previous.city, current.city) ||
      !_nullableStringsEqual(previous.countryCode, current.countryCode)) {
    changed.add(EventDuplicateFieldGroup.location);
  }
  if (previous.startAt.toUtc() != current.startAt.toUtc() ||
      previous.endAt?.toUtc() != current.endAt?.toUtc() ||
      previous.isDateOnly != current.isDateOnly ||
      !_nullableStringsEqual(previous.timeZone, current.timeZone) ||
      !_nullableStringsEqual(previous.timeZoneSource, current.timeZoneSource)) {
    changed.add(EventDuplicateFieldGroup.schedule);
  }
  if (!_nullableStringsEqual(previous.websiteUrl, current.websiteUrl)) {
    changed.add(EventDuplicateFieldGroup.website);
  }
  return changed;
}

/// Snapshot stored on the duplicate at last review / mark-as-duplicate.
Map<String, dynamic> buildEventDuplicateReviewBaseline(ParkourEvent event) {
  return {
    'title': event.title,
    if (event.description != null && event.description!.trim().isNotEmpty)
      'description': event.description!.trim(),
    if (event.websiteUrl != null && event.websiteUrl!.trim().isNotEmpty)
      'websiteUrl': event.websiteUrl!.trim(),
    'imageUrls': List<String>.from(event.imageUrls),
    'spotIds': List<String>.from(event.spotIds),
    'spotListIds': List<String>.from(event.spotListIds),
    if (event.latitude != null) 'latitude': event.latitude,
    if (event.longitude != null) 'longitude': event.longitude,
    if (event.address != null && event.address!.trim().isNotEmpty)
      'address': event.address!.trim(),
    if (event.city != null && event.city!.trim().isNotEmpty)
      'city': event.city!.trim(),
    if (event.countryCode != null && event.countryCode!.trim().isNotEmpty)
      'countryCode': event.countryCode!.trim(),
    'startAt': Timestamp.fromDate(event.startAt.toUtc()),
    if (event.endAt != null) 'endAt': Timestamp.fromDate(event.endAt!.toUtc()),
    'isDateOnly': event.isDateOnly,
    if (event.timeZone != null && event.timeZone!.trim().isNotEmpty)
      'timeZone': event.timeZone!.trim(),
    if (event.timeZoneSource != null && event.timeZoneSource!.trim().isNotEmpty)
      'timeZoneSource': event.timeZoneSource!.trim(),
  };
}

/// Clears pending-change flags and rewrites the baseline to current fields.
Map<String, dynamic> buildDuplicateReviewAcknowledgedUpdates(
  ParkourEvent event,
) {
  return {
    'duplicateReviewBaseline': buildEventDuplicateReviewBaseline(event),
    'duplicateChangedFields': FieldValue.delete(),
    'duplicateHasPendingChanges': false,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Deletes review fields together with duplicate status.
Map<String, dynamic> buildDuplicateReviewClearUpdates() {
  return {
    'duplicateReviewBaseline': FieldValue.delete(),
    'duplicateChangedFields': FieldValue.delete(),
    'duplicateHasPendingChanges': FieldValue.delete(),
  };
}

String formatEventDuplicateFieldGroupValue({
  required BuildContext context,
  required ParkourEvent event,
  required EventDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  switch (group) {
    case EventDuplicateFieldGroup.photos:
      return l10n.eventDuplicateChangesPhotosValue(event.imageUrls.length);
    case EventDuplicateFieldGroup.linkedSpots:
      return l10n.eventDuplicateChangesLinkedSpotsValue(
        event.spotIds.length + event.spotListIds.length,
      );
    case EventDuplicateFieldGroup.title:
      final title = event.title.trim();
      return title.isEmpty ? l10n.eventDuplicateChangesNoValue : title;
    case EventDuplicateFieldGroup.description:
      final description = event.description?.trim() ?? '';
      if (description.isEmpty) return l10n.eventDuplicateChangesNoValue;
      if (description.length <= 80) return description;
      return '${description.substring(0, 79)}…';
    case EventDuplicateFieldGroup.location:
      final city = event.city?.trim();
      if (city != null && city.isNotEmpty) return city;
      final address = event.address?.trim();
      if (address != null && address.isNotEmpty) return address;
      if (event.latitude != null && event.longitude != null) {
        return '${event.latitude!.toStringAsFixed(5)}, '
            '${event.longitude!.toStringAsFixed(5)}';
      }
      return l10n.eventDuplicateChangesNoValue;
    case EventDuplicateFieldGroup.schedule:
      final material = MaterialLocalizations.of(context);
      final start = event.startAt.toLocal();
      final date = material.formatMediumDate(start);
      if (event.isDateOnly) return date;
      final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(start));
      return '$date $time';
    case EventDuplicateFieldGroup.website:
      final website = event.websiteUrl?.trim() ?? '';
      return website.isEmpty ? l10n.eventDuplicateChangesNoValue : website;
  }
}
