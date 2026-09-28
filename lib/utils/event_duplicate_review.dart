import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import 'duplicate_field_comparison.dart';

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
  required BuildContext? context,
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
      return description;
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
      if (context == null) return event.startAt.toUtc().toIso8601String();
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

/// Display model for a stored review baseline. Null when none was saved.
ParkourEvent? eventFromDuplicateReviewBaseline(Map<String, dynamic>? baseline) {
  if (baseline == null) return null;
  return ParkourEvent.fromMap(baseline);
}

/// Whether [native] still matches [previous] for [group].
/// Null when either record is missing.
bool? eventDuplicateNativeMatchesPrevious({
  required ParkourEvent? previous,
  required ParkourEvent? native,
  required EventDuplicateFieldGroup group,
}) {
  if (previous == null || native == null) return null;
  return !changedEventDuplicateFieldGroups(
    previous: previous,
    current: native,
  ).contains(group);
}

/// External from/to lines and the native match for one changed group.
DuplicateFieldComparison buildEventDuplicateFieldComparison({
  required BuildContext? context,
  required ParkourEvent current,
  required ParkourEvent? previous,
  required ParkourEvent? native,
  required EventDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  final summary = _eventSummary(context, current, group, l10n);
  final nativeSummary = native == null
      ? null
      : _eventSummary(context, native, group, l10n);
  if (previous == null) {
    return DuplicateFieldComparison(
      lines: const [],
      currentSummary: summary,
      nativeSummary: nativeSummary,
      previousUnavailable: true,
      nativeUnavailable: native == null,
    );
  }
  return DuplicateFieldComparison(
    lines: _eventChangeLines(
      context: context,
      previous: previous,
      current: current,
      native: native,
      group: group,
      l10n: l10n,
    ),
    currentSummary: summary,
    nativeSummary: nativeSummary,
    previousUnavailable: false,
    nativeUnavailable: native == null,
    nativeMatchesPrevious: eventDuplicateNativeMatchesPrevious(
      previous: previous,
      native: native,
      group: group,
    ),
  );
}

String _eventSummary(
  BuildContext? context,
  ParkourEvent event,
  EventDuplicateFieldGroup group,
  AppLocalizations l10n,
) {
  return formatEventDuplicateFieldGroupValue(
    context: context,
    event: event,
    group: group,
    l10n: l10n,
  );
}

String _displayText(String? value, AppLocalizations l10n) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return l10n.eventDuplicateChangesNoValue;
  }
  return trimmed;
}

String _nativeText(String? value) => value ?? '';

String _eventCoordinates(ParkourEvent event, AppLocalizations l10n) {
  final latitude = event.latitude;
  final longitude = event.longitude;
  if (latitude == null || longitude == null) {
    return l10n.eventDuplicateChangesNoValue;
  }
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

String _formatInstant({
  required BuildContext? context,
  required DateTime? instant,
  required bool isDateOnly,
  required AppLocalizations l10n,
}) {
  if (instant == null) return l10n.eventDuplicateChangesNoValue;
  if (context == null) return instant.toUtc().toIso8601String();
  final material = MaterialLocalizations.of(context);
  final local = instant.toLocal();
  final date = material.formatMediumDate(local);
  if (isDateOnly) return date;
  final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date $time';
}

DuplicateChangeLine _countLine({
  required String from,
  required String to,
  required String native,
  required bool sameCount,
  required bool contentsEqual,
}) {
  return DuplicateChangeLine(
    from: from,
    to: to,
    native: native,
    contentsChanged: sameCount && !contentsEqual,
  );
}

void _addLine({
  required List<DuplicateChangeLine> lines,
  required bool changed,
  required String label,
  required String from,
  required String to,
  required String native,
}) {
  if (!changed) return;
  lines.add(
    DuplicateChangeLine(label: label, from: from, to: to, native: native),
  );
}

List<DuplicateChangeLine> _eventChangeLines({
  required BuildContext? context,
  required ParkourEvent previous,
  required ParkourEvent current,
  required ParkourEvent? native,
  required EventDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  switch (group) {
    case EventDuplicateFieldGroup.photos:
      return [
        _countLine(
          from: l10n.eventDuplicateChangesPhotosValue(
            previous.imageUrls.length,
          ),
          to: l10n.eventDuplicateChangesPhotosValue(current.imageUrls.length),
          native: _nativeText(
            native == null
                ? null
                : l10n.eventDuplicateChangesPhotosValue(
                    native.imageUrls.length,
                  ),
          ),
          sameCount: previous.imageUrls.length == current.imageUrls.length,
          contentsEqual: _stringListsEqual(
            previous.imageUrls,
            current.imageUrls,
          ),
        ),
      ];
    case EventDuplicateFieldGroup.linkedSpots:
      final previousCount =
          previous.spotIds.length + previous.spotListIds.length;
      final currentCount = current.spotIds.length + current.spotListIds.length;
      final contentsEqual =
          _stringSetsEqual(previous.spotIds, current.spotIds) &&
          _stringSetsEqual(previous.spotListIds, current.spotListIds);
      return [
        _countLine(
          from: l10n.eventDuplicateChangesLinkedSpotsValue(previousCount),
          to: l10n.eventDuplicateChangesLinkedSpotsValue(currentCount),
          native: _nativeText(
            native == null
                ? null
                : l10n.eventDuplicateChangesLinkedSpotsValue(
                    native.spotIds.length + native.spotListIds.length,
                  ),
          ),
          sameCount: previousCount == currentCount,
          contentsEqual: contentsEqual,
        ),
      ];
    case EventDuplicateFieldGroup.title:
    case EventDuplicateFieldGroup.description:
    case EventDuplicateFieldGroup.website:
      return [
        DuplicateChangeLine(
          from: _eventSummary(context, previous, group, l10n),
          to: _eventSummary(context, current, group, l10n),
          native: _nativeText(
            native == null ? null : _eventSummary(context, native, group, l10n),
          ),
        ),
      ];
    case EventDuplicateFieldGroup.location:
      return _eventLocationLines(previous, current, native, l10n);
    case EventDuplicateFieldGroup.schedule:
      return _scheduleLines(context, previous, current, native, l10n);
  }
}

List<DuplicateChangeLine> _eventLocationLines(
  ParkourEvent previous,
  ParkourEvent current,
  ParkourEvent? native,
  AppLocalizations l10n,
) {
  final lines = <DuplicateChangeLine>[];
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.address, current.address),
    label: l10n.duplicateChangesAddress,
    from: _displayText(previous.address, l10n),
    to: _displayText(current.address, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.address, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.city, current.city),
    label: l10n.duplicateChangesCity,
    from: _displayText(previous.city, l10n),
    to: _displayText(current.city, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.city, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.countryCode, current.countryCode),
    label: l10n.duplicateChangesCountry,
    from: _displayText(previous.countryCode, l10n),
    to: _displayText(current.countryCode, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.countryCode, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed:
        previous.latitude != current.latitude ||
        previous.longitude != current.longitude,
    label: l10n.duplicateChangesCoordinates,
    from: _eventCoordinates(previous, l10n),
    to: _eventCoordinates(current, l10n),
    native: _nativeText(
      native == null ? null : _eventCoordinates(native, l10n),
    ),
  );
  if (lines.isNotEmpty) return lines;
  return [
    DuplicateChangeLine(
      from: _eventSummary(
        null,
        previous,
        EventDuplicateFieldGroup.location,
        l10n,
      ),
      to: _eventSummary(null, current, EventDuplicateFieldGroup.location, l10n),
      native: _nativeText(
        native == null
            ? null
            : _eventSummary(
                null,
                native,
                EventDuplicateFieldGroup.location,
                l10n,
              ),
      ),
    ),
  ];
}

List<DuplicateChangeLine> _scheduleLines(
  BuildContext? context,
  ParkourEvent previous,
  ParkourEvent current,
  ParkourEvent? native,
  AppLocalizations l10n,
) {
  final lines = <DuplicateChangeLine>[];
  final previousStart = _formatInstant(
    context: context,
    instant: previous.startAt,
    isDateOnly: previous.isDateOnly,
    l10n: l10n,
  );
  final currentStart = _formatInstant(
    context: context,
    instant: current.startAt,
    isDateOnly: current.isDateOnly,
    l10n: l10n,
  );
  _addLine(
    lines: lines,
    changed:
        previous.startAt.toUtc() != current.startAt.toUtc() ||
        previousStart != currentStart,
    label: l10n.duplicateChangesStart,
    from: previousStart,
    to: currentStart,
    native: _nativeText(
      native == null
          ? null
          : _formatInstant(
              context: context,
              instant: native.startAt,
              isDateOnly: native.isDateOnly,
              l10n: l10n,
            ),
    ),
  );
  _addLine(
    lines: lines,
    changed: previous.endAt?.toUtc() != current.endAt?.toUtc(),
    label: l10n.duplicateChangesEnd,
    from: _formatInstant(
      context: context,
      instant: previous.endAt,
      isDateOnly: previous.isDateOnly,
      l10n: l10n,
    ),
    to: _formatInstant(
      context: context,
      instant: current.endAt,
      isDateOnly: current.isDateOnly,
      l10n: l10n,
    ),
    native: _nativeText(
      native == null
          ? null
          : _formatInstant(
              context: context,
              instant: native.endAt,
              isDateOnly: native.isDateOnly,
              l10n: l10n,
            ),
    ),
  );
  _addLine(
    lines: lines,
    changed: previous.isDateOnly != current.isDateOnly,
    label: l10n.duplicateChangesDateOnly,
    from: previous.isDateOnly
        ? l10n.duplicateChangesYes
        : l10n.duplicateChangesNo,
    to: current.isDateOnly ? l10n.duplicateChangesYes : l10n.duplicateChangesNo,
    native: _nativeText(
      native == null
          ? null
          : (native.isDateOnly
                ? l10n.duplicateChangesYes
                : l10n.duplicateChangesNo),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.timeZone, current.timeZone),
    label: l10n.duplicateChangesTimeZone,
    from: _displayText(previous.timeZone, l10n),
    to: _displayText(current.timeZone, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.timeZone, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(
      previous.timeZoneSource,
      current.timeZoneSource,
    ),
    label: l10n.duplicateChangesTimeZoneSource,
    from: _displayText(previous.timeZoneSource, l10n),
    to: _displayText(current.timeZoneSource, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.timeZoneSource, l10n),
    ),
  );
  if (lines.isNotEmpty) return lines;
  return [
    DuplicateChangeLine(
      from: _eventSummary(
        context,
        previous,
        EventDuplicateFieldGroup.schedule,
        l10n,
      ),
      to: _eventSummary(
        context,
        current,
        EventDuplicateFieldGroup.schedule,
        l10n,
      ),
      native: _nativeText(
        native == null
            ? null
            : _eventSummary(
                context,
                native,
                EventDuplicateFieldGroup.schedule,
                l10n,
              ),
      ),
    ),
  ];
}
