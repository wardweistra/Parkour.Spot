import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/event_report.dart';

class EventReportService {
  EventReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> statuses = <String>[
    'New',
    'Reviewing',
    'Approved',
    'Rejected',
  ];

  Future<bool> submitEventReport({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    bool isDateOnly = false,
    String? timeZone,
    String? description,
    String? websiteUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    List<String> spotIds = const <String>[],
    List<String> spotListIds = const <String>[],
    String? linkedSpotName,
    String? linkedSpotListName,
    String? reporterUserId,
    String? reporterName,
    String? reporterEmail,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return false;

    final normalizedWebsiteUrl = websiteUrl?.trim();
    final normalizedSpotIds = spotIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final normalizedSpotListIds = spotListIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    try {
      await _firestore.collection('eventReports').add({
        'title': trimmedTitle,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (normalizedWebsiteUrl != null && normalizedWebsiteUrl.isNotEmpty)
          'websiteUrl': normalizedWebsiteUrl,
        'startAt': Timestamp.fromDate(startAt.toUtc()),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt.toUtc()),
        if (isDateOnly) 'isDateOnly': true,
        if (timeZone != null && timeZone.trim().isNotEmpty)
          'timeZone': timeZone.trim(),
        if (latitude != null && longitude != null) ...{
          'latitude': latitude,
          'longitude': longitude,
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          if (countryCode != null && countryCode.trim().isNotEmpty)
            'countryCode': countryCode.trim().toUpperCase(),
        },
        'spotIds': normalizedSpotIds,
        'spotListIds': normalizedSpotListIds,
        if (linkedSpotName != null && linkedSpotName.trim().isNotEmpty)
          'linkedSpotName': linkedSpotName.trim(),
        if (linkedSpotListName != null && linkedSpotListName.trim().isNotEmpty)
          'linkedSpotListName': linkedSpotListName.trim(),
        if (reporterUserId != null && reporterUserId.isNotEmpty)
          'reporterUserId': reporterUserId,
        if (reporterName != null && reporterName.trim().isNotEmpty)
          'reporterName': reporterName.trim(),
        if (reporterEmail != null && reporterEmail.trim().isNotEmpty)
          'reporterEmail': reporterEmail.trim(),
        'status': statuses.first,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting event report: $e');
      return false;
    }
  }

  Future<bool> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewedBy,
    String? reviewedByName,
  }) async {
    if (!statuses.contains(status)) return false;

    try {
      await _firestore.collection('eventReports').doc(reportId).update({
        'status': status,
        if (reviewedBy != null && reviewedBy.isNotEmpty)
          'reviewedBy': reviewedBy,
        if (reviewedByName != null && reviewedByName.isNotEmpty)
          'reviewedByName': reviewedByName,
        if (status != statuses.first)
          'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating event report status: $e');
      return false;
    }
  }

  Future<String?> approveReport({
    required String reportId,
    required String approverUserId,
    String? approverName,
    String? moderatorNotes,
  }) async {
    try {
      final result = await _firestore.runTransaction<String?>((
        transaction,
      ) async {
        final reportRef = _firestore.collection('eventReports').doc(reportId);
        final snapshot = await transaction.get(reportRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Event report not found');
        }

        final report = EventReport.fromSnapshot(snapshot);
        if (report.status == 'Approved' && report.approvedEventId != null) {
          return report.approvedEventId;
        }

        final eventData = _buildEventData(
          report: report,
          approverUserId: approverUserId,
        );
        if (eventData == null) {
          throw StateError('Invalid event report data');
        }

        final eventRef = _firestore.collection('events').doc();
        transaction.set(eventRef, eventData);
        transaction.update(reportRef, {
          'status': 'Approved',
          'approvedEventId': eventRef.id,
          'reviewedBy': approverUserId,
          if (approverName != null && approverName.trim().isNotEmpty)
            'reviewedByName': approverName.trim(),
          if (moderatorNotes != null && moderatorNotes.trim().isNotEmpty)
            'moderatorNotes': moderatorNotes.trim(),
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return eventRef.id;
      });
      return result;
    } catch (e) {
      debugPrint('Error approving event report: $e');
      return null;
    }
  }

  Future<bool> rejectReport({
    required String reportId,
    required String reviewerUserId,
    String? reviewerName,
    String? moderatorNotes,
  }) async {
    try {
      await _firestore.collection('eventReports').doc(reportId).update({
        'status': 'Rejected',
        'reviewedBy': reviewerUserId,
        if (reviewerName != null && reviewerName.trim().isNotEmpty)
          'reviewedByName': reviewerName.trim(),
        if (moderatorNotes != null && moderatorNotes.trim().isNotEmpty)
          'moderatorNotes': moderatorNotes.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error rejecting event report: $e');
      return false;
    }
  }

  Stream<List<EventReport>> watchEventReports() {
    return _firestore
        .collection('eventReports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventReport.fromSnapshot(doc))
              .toList(growable: false),
        );
  }

  Map<String, dynamic>? _buildEventData({
    required EventReport report,
    required String approverUserId,
  }) {
    final title = report.title.trim();
    if (title.isEmpty) return null;
    final normalizedDescription = report.description?.trim();
    final normalizedWebsiteUrl = report.websiteUrl?.trim();
    final normalizedSpotIds = report.spotIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final normalizedSpotListIds = report.spotListIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(10)
        .toList();
    final startAt = report.startAt.toUtc();
    final endAt = report.endAt?.toUtc();
    if (endAt != null && endAt.isBefore(startAt)) {
      return null;
    }

    final hasLatLng = report.latitude != null && report.longitude != null;
    final hasAddress = report.address?.trim().isNotEmpty == true;

    return <String, dynamic>{
      'title': title,
      if (normalizedDescription != null && normalizedDescription.isNotEmpty)
        'description': normalizedDescription,
      if (normalizedWebsiteUrl != null && normalizedWebsiteUrl.isNotEmpty)
        'websiteUrl': normalizedWebsiteUrl,
      'startAt': Timestamp.fromDate(startAt),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt),
      if (report.isDateOnly) 'isDateOnly': true,
      if (report.timeZone != null && report.timeZone!.trim().isNotEmpty)
        'timeZone': report.timeZone!.trim(),
      if (hasLatLng && hasAddress) ...{
        'latitude': report.latitude,
        'longitude': report.longitude,
        'address': report.address!.trim(),
        if (report.city != null && report.city!.trim().isNotEmpty)
          'city': report.city!.trim(),
        if (report.countryCode != null && report.countryCode!.trim().isNotEmpty)
          'countryCode': report.countryCode!.trim().toUpperCase(),
      },
      'spotIds': normalizedSpotIds,
      'spotListIds': normalizedSpotListIds,
      'createdBy': approverUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
