import 'package:flutter/material.dart';

import '../models/audit_log.dart';
import '../models/audit_log_entry.dart';

/// High-level buckets for filtering the admin audit log feed.
enum AuditLogCategory {
  spotSyncs,
  eventSyncs,
  moderatorActions,
  creations,
}

/// Default window step for load older / load newer.
const Duration auditLogWindowStep = Duration(hours: 24);

/// Categories that should be selected when the screen first opens.
Set<AuditLogCategory> defaultSelectedAuditLogCategories() =>
    Set<AuditLogCategory>.from(AuditLogCategory.values);

/// Maps a creation-style feed entry type to its category.
AuditLogCategory auditLogCategoryForEntryType(AuditLogEntryType type) {
  switch (type) {
    case AuditLogEntryType.spotCreation:
    case AuditLogEntryType.userCreation:
    case AuditLogEntryType.spotReportCreation:
    case AuditLogEntryType.ratingCreation:
    case AuditLogEntryType.syncSourceCreation:
      return AuditLogCategory.creations;
    case AuditLogEntryType.auditLogAction:
      return AuditLogCategory.moderatorActions;
  }
}

/// Maps a durable auditLog action to its category.
AuditLogCategory auditLogCategoryForAction(AuditLogAction action) {
  switch (action) {
    case AuditLogAction.spotSourceSync:
      return AuditLogCategory.spotSyncs;
    case AuditLogAction.eventSourceSync:
      return AuditLogCategory.eventSyncs;
    case AuditLogAction.eventCreate:
      return AuditLogCategory.creations;
    case AuditLogAction.spotEdit:
    case AuditLogAction.spotMarkedAsDuplicate:
    case AuditLogAction.spotHidden:
    case AuditLogAction.spotUnhidden:
    case AuditLogAction.eventMarkedAsDuplicate:
    case AuditLogAction.eventDuplicateChangesApplied:
    case AuditLogAction.eventDuplicateChangesDismissed:
    case AuditLogAction.spotDuplicateChangesApplied:
    case AuditLogAction.spotDuplicateChangesDismissed:
    case AuditLogAction.eventHidden:
    case AuditLogAction.eventUnhidden:
    case AuditLogAction.spotReportStatusChange:
    case AuditLogAction.spotDelete:
    case AuditLogAction.photoAdded:
    case AuditLogAction.photoRejected:
    case AuditLogAction.eventEdit:
    case AuditLogAction.eventReportStatusChange:
    case AuditLogAction.eventDuplicateCleared:
    case AuditLogAction.userModeratorChanged:
    case AuditLogAction.userAdminChanged:
    case AuditLogAction.syncSourceCreate:
    case AuditLogAction.syncSourceUpdate:
    case AuditLogAction.syncSourceDelete:
    case AuditLogAction.eventSyncSourceCreate:
    case AuditLogAction.eventSyncSourceUpdate:
    case AuditLogAction.eventSyncSourceDelete:
    case AuditLogAction.apiClientCreate:
    case AuditLogAction.apiClientUpdate:
    case AuditLogAction.apiClientDelete:
      return AuditLogCategory.moderatorActions;
  }
}

/// Resolves [AuditLogAction] from feed metadata (`AuditLogAction.foo` or `foo`).
AuditLogAction? parseAuditLogActionFromMetadata(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final name = raw.contains('.') ? raw.split('.').last : raw;
  for (final action in AuditLogAction.values) {
    if (action.name == name) return action;
  }
  return null;
}

/// Category for a merged feed entry.
AuditLogCategory auditLogCategoryForEntry(AuditLogEntry entry) {
  if (entry.type == AuditLogEntryType.auditLogAction) {
    final action = parseAuditLogActionFromMetadata(entry.metadata?['action']);
    if (action != null) {
      return auditLogCategoryForAction(action);
    }
  }
  return auditLogCategoryForEntryType(entry.type);
}

/// Keeps entries whose category is in [selected]. Empty [selected] → empty list.
List<AuditLogEntry> filterAuditLogEntriesByCategories(
  Iterable<AuditLogEntry> entries,
  Set<AuditLogCategory> selected,
) {
  if (selected.isEmpty) return const [];
  return entries
      .where((entry) => selected.contains(auditLogCategoryForEntry(entry)))
      .toList(growable: false);
}

/// Extends the window start further into the past by [step].
DateTimeRange extendAuditLogRangeOlder(
  DateTimeRange range, {
  Duration step = auditLogWindowStep,
}) {
  return DateTimeRange(start: range.start.subtract(step), end: range.end);
}

/// Extends the window end toward [now] by [step], never past [now].
DateTimeRange extendAuditLogRangeNewer(
  DateTimeRange range, {
  DateTime? now,
  Duration step = auditLogWindowStep,
}) {
  final cappedNow = now ?? DateTime.now();
  final candidate = range.end.add(step);
  final newEnd = candidate.isAfter(cappedNow) ? cappedNow : candidate;
  if (!newEnd.isAfter(range.end)) {
    return DateTimeRange(start: range.start, end: cappedNow);
  }
  return DateTimeRange(start: range.start, end: newEnd);
}

/// True when the window end is meaningfully before [now] (can load newer).
bool canExtendAuditLogRangeNewer(
  DateTimeRange range, {
  DateTime? now,
  Duration epsilon = const Duration(minutes: 1),
}) {
  final cappedNow = now ?? DateTime.now();
  return range.end.isBefore(cappedNow.subtract(epsilon));
}

/// Sync run id from a merged feed entry, when the audit row linked one.
/// Prefers nested Firestore `metadata.runId` (as stored on [AuditLogEntry]).
String? syncRunIdFromAuditLogEntry(AuditLogEntry entry) {
  final nested = entry.metadata?['metadata'];
  if (nested is Map) {
    final runId = nested['runId'];
    if (runId is String && runId.trim().isNotEmpty) {
      return runId.trim();
    }
  }
  final top = entry.metadata?['runId'];
  if (top is String && top.trim().isNotEmpty) {
    return top.trim();
  }
  return null;
}
