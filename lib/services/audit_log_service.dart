import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log a spot edit with field changes
  Future<void> logSpotEdit({
    required String spotId,
    required String? userId,
    required String? userName,
    required Map<String, dynamic> changes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotEdit.toString().split('.').last,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'changes': changes,
      });
    } catch (e) {
      debugPrint('Error logging spot edit: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Log when a spot is marked as duplicate
  Future<void> logSpotMarkedAsDuplicate({
    required String spotId,
    required String originalSpotId,
    required String? userId,
    required String? userName,
    bool transferPhotos = false,
    bool transferYoutubeLinks = false,
    bool overwriteName = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSpotAttributes = false,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotMarkedAsDuplicate.toString().split('.').last,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'originalSpotId': originalSpotId,
          'transferPhotos': transferPhotos,
          'transferYoutubeLinks': transferYoutubeLinks,
          'overwriteName': overwriteName,
          'overwriteDescription': overwriteDescription,
          'overwriteLocation': overwriteLocation,
          'overwriteSpotAttributes': overwriteSpotAttributes,
        },
      });
    } catch (e) {
      debugPrint('Error logging duplicate marking: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Get audit logs for a specific spot
  Future<List<AuditLog>> getAuditLogsForSpot(String spotId, {int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('auditLog')
          .where('spotId', isEqualTo: spotId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => AuditLog.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting audit logs for spot: $e');
      return [];
    }
  }

  /// Log when a spot is hidden or unhidden
  Future<void> logSpotHidden({
    required String spotId,
    required bool hidden,
    required String? userId,
    required String? userName,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': (hidden ? AuditLogAction.spotHidden : AuditLogAction.spotUnhidden).toString().split('.').last,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'hidden': hidden,
        },
      });
    } catch (e) {
      debugPrint('Error logging spot hidden/unhidden: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Get audit logs for a specific user
  Future<List<AuditLog>> getAuditLogsForUser(String userId, {int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('auditLog')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => AuditLog.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting audit logs for user: $e');
      return [];
    }
  }

  /// Log when a spot report status is changed
  Future<void> logSpotReportStatusChange({
    required String reportId,
    required String spotId,
    required String oldStatus,
    required String newStatus,
    required String? userId,
    required String? userName,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotReportStatusChange.toString().split('.').last,
        'reportId': reportId,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'changes': {
          'status': {
            'from': oldStatus,
            'to': newStatus,
          },
        },
      });
    } catch (e) {
      debugPrint('Error logging spot report status change: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Log when a spot is deleted
  Future<void> logSpotDelete({
    required String spotId,
    required String? userId,
    required String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotDelete.toString().split('.').last,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        if (metadata != null) 'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error logging spot delete: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }
}

