/// Entry kinds merged into the admin audit log feed.
///
/// Entity-sourced types (spot / user / spot report / rating creates) are built
/// from collection `createdAt` queries. Do not add new entity merges — durable
/// ops (including spot lists) write to `auditLog` and use [auditLogAction].
/// The community-activity chip covers organic creates, event create, and
/// spot-list CRUD.
enum AuditLogEntryType {
  spotCreation,
  userCreation,
  spotReportCreation,
  ratingCreation,
  auditLogAction,
}

/// One row in the merged admin audit log timeline.
class AuditLogEntry {
  final AuditLogEntryType type;
  final DateTime timestamp;
  final String? id;
  final String? title;
  final String? subtitle;
  final String? details;
  final Map<String, dynamic>? metadata;

  AuditLogEntry({
    required this.type,
    required this.timestamp,
    this.id,
    this.title,
    this.subtitle,
    this.details,
    this.metadata,
  });
}
