import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditLogAction {
  spotEdit,
  spotMarkedAsDuplicate,
  spotHidden,
  spotUnhidden,
  spotReportStatusChange,
}

class AuditLog {
  final String? id;
  final AuditLogAction action;
  final String spotId;
  final String? reportId; // Optional report ID for spot report-related actions
  final String? userId;
  final String? userName;
  final DateTime timestamp;
  final Map<String, dynamic>? changes; // Field changes: {field: {from: value, to: value}}
  final Map<String, dynamic>? metadata; // Additional metadata (e.g., originalSpotId for duplicates)

  AuditLog({
    this.id,
    required this.action,
    required this.spotId,
    this.reportId,
    this.userId,
    this.userName,
    required this.timestamp,
    this.changes,
    this.metadata,
  });

  factory AuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      action: AuditLogAction.values.firstWhere(
        (e) => e.toString().split('.').last == data['action'],
        orElse: () => AuditLogAction.spotEdit,
      ),
      spotId: data['spotId'] as String,
      reportId: data['reportId'] as String?,
      userId: data['userId'] as String?,
      userName: data['userName'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changes: data['changes'] as Map<String, dynamic>?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'action': action.toString().split('.').last,
      'spotId': spotId,
      if (reportId != null) 'reportId': reportId,
      'userId': userId,
      'userName': userName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (changes != null) 'changes': changes,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

