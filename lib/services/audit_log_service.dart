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
    String? reportId,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final meta = Map<String, dynamic>.from(metadata ?? {});
      if (notes != null && notes.isNotEmpty) {
        meta['notes'] = notes;
      }
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotEdit.toString().split('.').last,
        'spotId': spotId,
        if (reportId != null) 'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'changes': changes,
        if (meta.isNotEmpty) 'metadata': meta,
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
    String? reportId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotMarkedAsDuplicate
            .toString()
            .split('.')
            .last,
        'spotId': spotId,
        if (reportId != null) 'reportId': reportId,
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
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging duplicate marking: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Get audit logs for a specific spot
  Future<List<AuditLog>> getAuditLogsForSpot(
    String spotId, {
    int limit = 100,
  }) async {
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
    String? reportId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action':
            (hidden ? AuditLogAction.spotHidden : AuditLogAction.spotUnhidden)
                .toString()
                .split('.')
                .last,
        'spotId': spotId,
        if (reportId != null) 'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'hidden': hidden,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging spot hidden/unhidden: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Log when an event is marked as duplicate
  Future<void> logEventMarkedAsDuplicate({
    required String eventId,
    required String originalEventId,
    required String? userId,
    required String? userName,
    bool transferPhotos = false,
    bool transferLinkedSpots = false,
    bool overwriteTitle = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSchedule = false,
    bool overwriteWebsite = false,
    String? reportId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.eventMarkedAsDuplicate
            .toString()
            .split('.')
            .last,
        'eventId': eventId,
        if (reportId != null) 'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'originalEventId': originalEventId,
          'transferPhotos': transferPhotos,
          'transferLinkedSpots': transferLinkedSpots,
          'overwriteTitle': overwriteTitle,
          'overwriteDescription': overwriteDescription,
          'overwriteLocation': overwriteLocation,
          'overwriteSchedule': overwriteSchedule,
          'overwriteWebsite': overwriteWebsite,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging event duplicate marking: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  Future<void> logEventDuplicateChangesReviewed({
    required String eventId,
    required String originalEventId,
    required bool applied,
    required String? userId,
    required String? userName,
    bool transferPhotos = false,
    bool transferLinkedSpots = false,
    bool overwriteTitle = false,
    bool overwriteDescription = false,
    bool overwriteLocation = false,
    bool overwriteSchedule = false,
    bool overwriteWebsite = false,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action':
            (applied
                    ? AuditLogAction.eventDuplicateChangesApplied
                    : AuditLogAction.eventDuplicateChangesDismissed)
                .toString()
                .split('.')
                .last,
        'eventId': eventId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'originalEventId': originalEventId,
          if (applied) ...{
            'transferPhotos': transferPhotos,
            'transferLinkedSpots': transferLinkedSpots,
            'overwriteTitle': overwriteTitle,
            'overwriteDescription': overwriteDescription,
            'overwriteLocation': overwriteLocation,
            'overwriteSchedule': overwriteSchedule,
            'overwriteWebsite': overwriteWebsite,
          },
        },
      });
    } catch (e) {
      debugPrint('Error logging event duplicate change review: $e');
    }
  }

  /// Log when an event is hidden or unhidden
  Future<void> logEventHidden({
    required String eventId,
    required bool hidden,
    required String? userId,
    required String? userName,
    String? reportId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action':
            (hidden ? AuditLogAction.eventHidden : AuditLogAction.eventUnhidden)
                .toString()
                .split('.')
                .last,
        'eventId': eventId,
        if (reportId != null) 'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'hidden': hidden,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging event hidden/unhidden: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Get audit logs for a specific user
  Future<List<AuditLog>> getAuditLogsForUser(
    String userId, {
    int limit = 100,
  }) async {
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
        'action': AuditLogAction.spotReportStatusChange
            .toString()
            .split('.')
            .last,
        'reportId': reportId,
        'spotId': spotId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'changes': {
          'status': {'from': oldStatus, 'to': newStatus},
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
    String? reportId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.spotDelete.toString().split('.').last,
        'spotId': spotId,
        if (reportId != null) 'reportId': reportId,
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

  /// Log when photos are added to a spot
  Future<void> logPhotoAdded({
    required String spotId,
    required List<String> photoUrls,
    required String? userId,
    required String? userName,
    String? reportId,
    List<String>? originalPhotoUrls,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.photoAdded.toString().split('.').last,
        'spotId': spotId,
        if (reportId != null) 'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'photoUrls': photoUrls,
          if (originalPhotoUrls != null) 'originalPhotoUrls': originalPhotoUrls,
          'contributor': {'userId': userId, 'userName': userName},
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging photo addition: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }

  /// Log when photo suggestions are rejected
  Future<void> logPhotoRejected({
    required String spotId,
    required String reportId,
    required List<String> originalPhotoUrls,
    required List<String> rejectedPhotoUrls,
    required String? userId,
    required String? userName,
    String? notes,
  }) async {
    try {
      await _firestore.collection('auditLog').add({
        'action': AuditLogAction.photoRejected.toString().split('.').last,
        'spotId': spotId,
        'reportId': reportId,
        'userId': userId,
        'userName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'originalPhotoUrls': originalPhotoUrls,
          'rejectedPhotoUrls': rejectedPhotoUrls,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      });
    } catch (e) {
      debugPrint('Error logging photo rejection: $e');
      // Don't throw - audit logging should not break the main operation
    }
  }
}
