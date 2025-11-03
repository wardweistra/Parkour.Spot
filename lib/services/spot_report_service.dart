import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for submitting spot reports to Firestore.
class SpotReportService {
  SpotReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
  }) async {
    if (!statuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Invalid report status');
    }

    try {
      await _firestore.collection('spotReports').doc(reportId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating report status: $e');
      return false;
    }
  }
}
