/// Entry kinds merged into the admin audit log feed.
enum AuditLogEntryType {
  spotCreation,
  userCreation,
  spotReportCreation,
  ratingCreation,
  syncSourceCreation,
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
