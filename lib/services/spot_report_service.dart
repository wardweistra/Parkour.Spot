import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/spot_report.dart';
import 'audit_log_service.dart';

/// Service responsible for submitting spot reports to Firestore.
class SpotReportService {
  SpotReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final AuditLogService _auditLogService = AuditLogService();

  /// Default categories shown to the user when reporting a spot.
  static const List<String> defaultCategories = <String>[
    'Spot closed or removed',
    'Inaccurate location or details',
    'Unsafe conditions',
    'Duplicate spot',
    'Other',
  ];

  /// Firestore status values a moderator can apply to a spot report.
  static const List<String> statuses = <String>['New', 'In Progress', 'Done'];

  /// Submits a spot report to Firestore. Returns true when the submission
  /// succeeds, otherwise false.
  Future<bool> submitSpotReport({
    required String spotId,
    required String spotName,
    required List<String> categories,
    String? otherCategory,
    String? details,
    String? contactEmail,
    String? reporterUserId,
    String? reporterEmail,
    String? spotCountryCode,
    String? spotCity,
  }) async {
    try {
      await _firestore.collection('spotReports').add({
        'spotId': spotId,
        'spotName': spotName,
        'categories': categories,
        if (otherCategory != null && otherCategory.isNotEmpty)
          'otherCategory': otherCategory,
        if (details != null && details.isNotEmpty) 'details': details,
        if (contactEmail != null && contactEmail.isNotEmpty)
          'contactEmail': contactEmail,
        if (reporterUserId != null && reporterUserId.isNotEmpty)
          'reporterUserId': reporterUserId,
        if (reporterEmail != null && reporterEmail.isNotEmpty)
          'reporterEmail': reporterEmail,
        if (spotCountryCode != null && spotCountryCode.isNotEmpty)
          'spotCountryCode': spotCountryCode,
        if (spotCity != null && spotCity.isNotEmpty) 'spotCity': spotCity,
        'status': statuses.first, // default "New"
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting spot report: $e');
      return false;
    }
  }

  /// Updates the status of a spot report. Intended for moderators.
  Future<bool> updateReportStatus({
    required String reportId,
    required String status,
    String? userId,
    String? userName,
  }) async {
    if (!statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Invalid report status');
    }

    try {
      // Get the current report to retrieve old status and spotId
      final reportDoc = await _firestore.collection('spotReports').doc(reportId).get();
      if (!reportDoc.exists) {
        debugPrint('Report $reportId does not exist');
        return false;
      }

      final reportData = reportDoc.data()!;
      final oldStatus = reportData['status'] as String? ?? 'New';
      final spotId = reportData['spotId'] as String? ?? '';

      // Update the status
      await _firestore.collection('spotReports').doc(reportId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the status change
      await _auditLogService.logSpotReportStatusChange(
        reportId: reportId,
        spotId: spotId,
        oldStatus: oldStatus,
        newStatus: status,
        userId: userId,
        userName: userName,
      );

      return true;
    } catch (e) {
      debugPrint('Error updating report status: $e');
      return false;
    }
  }

  /// Streams all spot reports ordered by creation time.
  Stream<List<SpotReport>> watchSpotReports() {
    return _firestore
        .collection('spotReports')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SpotReport.fromSnapshot(doc))
            .toList(growable: false));
  }
}
