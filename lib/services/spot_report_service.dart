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

  /// Shared listener for all UI subscribers (avoids duplicate Firestore targets).
  Stream<List<SpotReport>>? _spotReportsStream;

  /// Default categories shown to the user when reporting a spot.
  static const List<String> defaultCategories = <String>[
    'Spot closed or removed',
    'Inaccurate location or details',
    'Unsafe conditions',
    'Not a spot',
    'Other',
  ];

  /// Firestore status values a moderator can apply to a spot report.
  static const List<String> statuses = <String>['New', 'Reviewing', 'Done'];

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
    String? reporterName,
    String? reporterEmail,
    String? spotCountryCode,
    String? spotCity,
    String? duplicateOfSpotId,
    List<String>? suggestedPhotoUrls,
    String? suggestedName,
    String? suggestedDescription,
    double? suggestedLatitude,
    double? suggestedLongitude,
    List<String>? suggestedGoodFor,
    List<String>? suggestedSpotFeatures,
    String? suggestedSpotAccess,
    Map<String, String>? suggestedSpotFacilities,
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
        if (reporterName != null && reporterName.isNotEmpty)
          'reporterName': reporterName,
        if (reporterEmail != null && reporterEmail.isNotEmpty)
          'reporterEmail': reporterEmail,
        if (spotCountryCode != null && spotCountryCode.isNotEmpty)
          'spotCountryCode': spotCountryCode,
        if (spotCity != null && spotCity.isNotEmpty) 'spotCity': spotCity,
        if (duplicateOfSpotId != null && duplicateOfSpotId.isNotEmpty)
          'duplicateOfSpotId': duplicateOfSpotId,
        if (suggestedPhotoUrls != null && suggestedPhotoUrls.isNotEmpty)
          'suggestedPhotoUrls': suggestedPhotoUrls,
        if (suggestedName != null && suggestedName.isNotEmpty)
          'suggestedName': suggestedName,
        if (suggestedDescription != null && suggestedDescription.isNotEmpty)
          'suggestedDescription': suggestedDescription,
        if (suggestedLatitude != null) 'suggestedLatitude': suggestedLatitude,
        if (suggestedLongitude != null) 'suggestedLongitude': suggestedLongitude,
        if (suggestedGoodFor != null && suggestedGoodFor.isNotEmpty)
          'suggestedGoodFor': suggestedGoodFor,
        if (suggestedSpotFeatures != null && suggestedSpotFeatures.isNotEmpty)
          'suggestedSpotFeatures': suggestedSpotFeatures,
        if (suggestedSpotAccess != null && suggestedSpotAccess.isNotEmpty)
          'suggestedSpotAccess': suggestedSpotAccess,
        if (suggestedSpotFacilities != null && suggestedSpotFacilities.isNotEmpty)
          'suggestedSpotFacilities': suggestedSpotFacilities,
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

  /// Updates a spot report with approved photo URLs (moves from suggestedPhotoUrls to acceptedPhotoUrls)
  Future<bool> updateReportWithApprovedPhotos({
    required String reportId,
    required List<String> originalPhotoUrls, // Original URLs from /suggestions/
    required List<String> approvedPhotoUrls, // New URLs from /spots/
    String? moderatorNotes,
    String? userId,
    String? userName,
  }) async {
    try {
      // Get the current report
      final reportDoc = await _firestore.collection('spotReports').doc(reportId).get();
      if (!reportDoc.exists) {
        debugPrint('Report $reportId does not exist');
        return false;
      }

      final reportData = reportDoc.data()!;
      final currentSuggestedUrls = (reportData['suggestedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];

      // Remove original photos from suggestedPhotoUrls (using original URLs)
      final updatedSuggestedUrls = currentSuggestedUrls
          .where((url) => !originalPhotoUrls.contains(url))
          .toList();

      // Get existing accepted URLs and add new ones
      final currentAcceptedUrls = (reportData['acceptedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];
      final updatedAcceptedUrls = <String>[...currentAcceptedUrls, ...approvedPhotoUrls];

      // Update the report
      await _firestore.collection('spotReports').doc(reportId).update({
        'suggestedPhotoUrls': updatedSuggestedUrls.isEmpty ? FieldValue.delete() : updatedSuggestedUrls,
        'acceptedPhotoUrls': updatedAcceptedUrls,
        if (moderatorNotes != null && moderatorNotes.isNotEmpty)
          'moderatorNotes': moderatorNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error updating report with approved photos: $e');
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

  /// Updates a spot report with rejected photo URLs (moves photos from suggestedPhotoUrls to rejectedPhotoUrls)
  Future<bool> updateReportWithRejectedPhotos({
    required String reportId,
    required String spotId,
    required List<String> originalPhotoUrls, // Original URLs from /suggestions/
    required List<String> rejectedPhotoUrls, // New URLs from /rejected/
    String? moderatorNotes,
    String? userId,
    String? userName,
  }) async {
    try {
      // Get the current report
      final reportDoc = await _firestore.collection('spotReports').doc(reportId).get();
      if (!reportDoc.exists) {
        debugPrint('Report $reportId does not exist');
        return false;
      }

      final reportData = reportDoc.data()!;
      final currentSuggestedUrls = (reportData['suggestedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];

      // Remove original photos from suggestedPhotoUrls (using original URLs, not new rejected URLs)
      final updatedSuggestedUrls = currentSuggestedUrls
          .where((url) => !originalPhotoUrls.contains(url))
          .toList();

      // Get existing rejected URLs and add new ones
      final currentRejectedUrls = (reportData['rejectedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];
      final updatedRejectedUrls = <String>[...currentRejectedUrls, ...rejectedPhotoUrls];

      // Update the report
      await _firestore.collection('spotReports').doc(reportId).update({
        'suggestedPhotoUrls': updatedSuggestedUrls.isEmpty ? FieldValue.delete() : updatedSuggestedUrls,
        'rejectedPhotoUrls': updatedRejectedUrls,
        if (moderatorNotes != null && moderatorNotes.isNotEmpty)
          'moderatorNotes': moderatorNotes,
        'status': 'Done',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log to audit trail
      if (userId != null && userName != null) {
        await _auditLogService.logPhotoRejected(
          spotId: spotId,
          reportId: reportId,
          originalPhotoUrls: originalPhotoUrls,
          rejectedPhotoUrls: rejectedPhotoUrls,
          userId: userId,
          userName: userName,
          notes: moderatorNotes,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating report with rejected photos: $e');
      return false;
    }
  }

  /// Updates a spot report with edit approval results (accepted and rejected fields).
  Future<bool> updateReportWithEditApprovals({
    required String reportId,
    required List<String> acceptedFields,
    required List<String> rejectedFields,
    String? moderatorNotes,
    String? userId,
    String? userName,
  }) async {
    try {
      final reportDoc = await _firestore.collection('spotReports').doc(reportId).get();
      if (!reportDoc.exists) {
        debugPrint('Report $reportId does not exist');
        return false;
      }

      await _firestore.collection('spotReports').doc(reportId).update({
        'acceptedEditFields': acceptedFields,
        'rejectedEditFields': rejectedFields,
        if (moderatorNotes != null && moderatorNotes.isNotEmpty)
          'moderatorNotes': moderatorNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error updating report with edit approvals: $e');
      return false;
    }
  }

  /// Undoes rejection by moving photos back from rejectedPhotoUrls to suggestedPhotoUrls
  Future<bool> undoPhotoRejection({
    required String reportId,
    required List<String> originalRejectedUrls, // Original URLs from /rejected/
    required List<String> restoredPhotoUrls, // New URLs from /suggestions/
    String? userId,
    String? userName,
  }) async {
    try {
      // Get the current report
      final reportDoc = await _firestore.collection('spotReports').doc(reportId).get();
      if (!reportDoc.exists) {
        debugPrint('Report $reportId does not exist');
        return false;
      }

      final reportData = reportDoc.data()!;
      final currentSuggestedUrls = (reportData['suggestedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];
      final currentRejectedUrls = (reportData['rejectedPhotoUrls'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? <String>[];

      // Add restored photos back to suggestedPhotoUrls (using new URLs from /suggestions/)
      final updatedSuggestedUrls = <String>[...currentSuggestedUrls, ...restoredPhotoUrls];

      // Remove original rejected photos from rejectedPhotoUrls (using original URLs, not new suggested URLs)
      final updatedRejectedUrls = currentRejectedUrls
          .where((url) => !originalRejectedUrls.contains(url))
          .toList();

      // Update the report
      await _firestore.collection('spotReports').doc(reportId).update({
        'suggestedPhotoUrls': updatedSuggestedUrls,
        'rejectedPhotoUrls': updatedRejectedUrls.isEmpty ? FieldValue.delete() : updatedRejectedUrls,
        'status': 'New', // Reset status to New so it appears in the queue again
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error undoing photo rejection: $e');
      return false;
    }
  }

  /// Streams all spot reports ordered by creation time.
  Stream<List<SpotReport>> watchSpotReports() {
    return _spotReportsStream ??= _firestore
        .collection('spotReports')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SpotReport.fromSnapshot(doc))
              .toList(growable: false),
        );
  }

  /// Gets all spot reports for a specific spot.
  /// Includes reports where the spot is the reported spot, or where the spot is mentioned as the original spot (duplicate reports).
  Future<List<SpotReport>> getReportsForSpot(String spotId) async {
    try {
      // Query for reports where this spot is the reported spot
      final directReportsQuery = _firestore
          .collection('spotReports')
          .where('spotId', isEqualTo: spotId);

      // Query for reports where this spot is mentioned as the original spot (duplicate reports)
      final duplicateReportsQuery = _firestore
          .collection('spotReports')
          .where('duplicateOfSpotId', isEqualTo: spotId);

      // Execute both queries in parallel
      final results = await Future.wait([
        directReportsQuery.get(),
        duplicateReportsQuery.get(),
      ]);

      // Combine results from both queries
      final allDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      allDocs.addAll(results[0].docs);
      allDocs.addAll(results[1].docs);

      // Convert to SpotReport objects, removing duplicates by ID
      final reportsMap = <String, SpotReport>{};
      for (final doc in allDocs) {
        final report = SpotReport.fromSnapshot(doc);
        reportsMap[report.id] = report;
      }

      final reports = reportsMap.values.toList();

      // Sort by creation date (newest first) in post-processing to avoid needing a composite index
      reports.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return reports;
    } catch (e) {
      debugPrint('Error getting reports for spot: $e');
      return [];
    }
  }
}
