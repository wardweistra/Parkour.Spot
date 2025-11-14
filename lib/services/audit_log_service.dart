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
}

