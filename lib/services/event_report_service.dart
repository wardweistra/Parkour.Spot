import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../utils/replay_latest_stream.dart';
import 'package:http/http.dart' as http;

import '../models/event_report.dart';
import '../utils/event_suggestion_utils.dart';
import '../utils/image_preparation.dart';

class EventReportService {
  EventReportService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const int maxSuggestedPhotos = 20;
  static const String eventSuggestionsPrefix = 'eventSuggestions/';
  static const String eventRejectedPrefix = 'eventRejected/';
  static const String eventsPrefix = 'events/';

  static const List<String> statuses = <String>[
    'New',
    'Reviewing',
    'Approved',
    'Rejected',
  ];

  /// Upload photos to [eventSuggestions/] (staging; does not trigger resize extension).
  Future<List<String>> uploadSuggestedEventPhotos(
    List<Uint8List> photoBytesList,
  ) async {
    if (photoBytesList.isEmpty) return const <String>[];
    if (photoBytesList.length > maxSuggestedPhotos) {
      throw StateError('At most $maxSuggestedPhotos photos allowed.');
    }

    final photoUrls = <String>[];
    for (var i = 0; i < photoBytesList.length; i++) {
      final prepared = await prepareImageForUpload(photoBytesList[i]);
      final ext = _extensionForContentType(prepared.contentType);
      final fileName =
          '$eventSuggestionsPrefix${DateTime.now().millisecondsSinceEpoch}_web_image_$i$ext';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putData(
        prepared.bytes,
        SettableMetadata(contentType: prepared.contentType),
      );
      final snapshot = await uploadTask;
      photoUrls.add(await snapshot.ref.getDownloadURL());
    }
    return photoUrls;
  }

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
    String? targetEventId,
    String? targetEventTitle,
    String? reporterUserId,
    String? reporterName,
    String? reporterEmail,
    String? suggestedTitle,
    String? suggestedDescription,
    String? suggestedWebsiteUrl,
    bool? suggestedIsDateOnly,
    String? suggestedTimeZone,
    DateTime? suggestedStartAt,
    DateTime? suggestedEndAt,
    List<String>? suggestedSpotIds,
    double? suggestedLatitude,
    double? suggestedLongitude,
    String? suggestedAddress,
    String? suggestedCity,
    String? suggestedCountryCode,
    bool suggestedLocationRemoved = false,
    List<String> suggestedPhotoUrls = const <String>[],
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
    final normalizedPhotoUrls = suggestedPhotoUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .take(maxSuggestedPhotos)
        .toList(growable: false);
    final normalizedSuggestedSpotIds =
        suggestedSpotIds
            ?.map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ?..sort();
    final normalizedTargetEventId = targetEventId?.trim();
    final normalizedTargetEventTitle = targetEventTitle?.trim();
    final normalizedSuggestedTitle = suggestedTitle?.trim();
    final normalizedSuggestedDescription = suggestedDescription?.trim();
    final normalizedSuggestedWebsiteUrl = suggestedWebsiteUrl?.trim();
    final normalizedSuggestedTimeZone = suggestedTimeZone?.trim();
    final normalizedSuggestedStartAt = suggestedStartAt?.toUtc();
    final normalizedSuggestedEndAt = suggestedEndAt?.toUtc();
    if (normalizedSuggestedStartAt != null &&
        normalizedSuggestedEndAt != null &&
        normalizedSuggestedEndAt.isBefore(normalizedSuggestedStartAt)) {
      return false;
    }

    try {
      final reportData = <String, dynamic>{
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
        if (normalizedTargetEventId != null &&
            normalizedTargetEventId.isNotEmpty)
          'targetEventId': normalizedTargetEventId,
        if (normalizedTargetEventTitle != null &&
            normalizedTargetEventTitle.isNotEmpty)
          'targetEventTitle': normalizedTargetEventTitle,
        if (reporterUserId != null && reporterUserId.isNotEmpty)
          'reporterUserId': reporterUserId,
        if (reporterName != null && reporterName.trim().isNotEmpty)
          'reporterName': reporterName.trim(),
        if (reporterEmail != null && reporterEmail.trim().isNotEmpty)
          'reporterEmail': reporterEmail.trim(),
        if (normalizedSuggestedTitle != null &&
            normalizedSuggestedTitle.isNotEmpty)
          'suggestedTitle': normalizedSuggestedTitle,
        if (normalizedSuggestedDescription != null &&
            normalizedSuggestedDescription.isNotEmpty)
          'suggestedDescription': normalizedSuggestedDescription,
        if (normalizedSuggestedWebsiteUrl != null &&
            normalizedSuggestedWebsiteUrl.isNotEmpty)
          'suggestedWebsiteUrl': normalizedSuggestedWebsiteUrl,
        if (normalizedSuggestedTimeZone != null &&
            normalizedSuggestedTimeZone.isNotEmpty)
          'suggestedTimeZone': normalizedSuggestedTimeZone,
        if (normalizedSuggestedStartAt != null)
          'suggestedStartAt': Timestamp.fromDate(normalizedSuggestedStartAt),
        if (normalizedSuggestedEndAt != null)
          'suggestedEndAt': Timestamp.fromDate(normalizedSuggestedEndAt),
        if (suggestedLatitude != null && suggestedLongitude != null) ...{
          'suggestedLatitude': suggestedLatitude,
          'suggestedLongitude': suggestedLongitude,
          if (suggestedAddress != null && suggestedAddress.trim().isNotEmpty)
            'suggestedAddress': suggestedAddress.trim(),
          if (suggestedCity != null && suggestedCity.trim().isNotEmpty)
            'suggestedCity': suggestedCity.trim(),
          if (suggestedCountryCode != null &&
              suggestedCountryCode.trim().isNotEmpty)
            'suggestedCountryCode': suggestedCountryCode.trim().toUpperCase(),
        },
        if (suggestedLocationRemoved) 'suggestedLocationRemoved': true,
        if (normalizedPhotoUrls.isNotEmpty)
          'suggestedPhotoUrls': normalizedPhotoUrls,
        'status': statuses.first,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (suggestedIsDateOnly != null) {
        reportData['suggestedIsDateOnly'] = suggestedIsDateOnly;
      }
      if (normalizedSuggestedSpotIds != null) {
        reportData['suggestedSpotIds'] = normalizedSuggestedSpotIds;
      }
      await _firestore.collection('eventReports').add(reportData);
      return true;
    } catch (e) {
      debugPrint('Error submitting event report: $e');
      return false;
    }
  }

  Future<bool> submitEventPhotoSuggestion({
    required String targetEventId,
    required String targetEventTitle,
    required DateTime startAt,
    DateTime? endAt,
    bool isDateOnly = false,
    String? timeZone,
    List<String> existingSpotIds = const <String>[],
    List<String> existingSpotListIds = const <String>[],
    List<String> suggestedPhotoUrls = const <String>[],
    String? reporterUserId,
    String? reporterName,
    String? reporterEmail,
  }) async {
    return submitEventReport(
      title: targetEventTitle,
      startAt: startAt,
      endAt: endAt,
      isDateOnly: isDateOnly,
      timeZone: timeZone,
      spotIds: existingSpotIds,
      spotListIds: existingSpotListIds,
      targetEventId: targetEventId,
      targetEventTitle: targetEventTitle,
      reporterUserId: reporterUserId,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      suggestedPhotoUrls: suggestedPhotoUrls,
    );
  }

  Future<bool> submitEventEditSuggestion({
    required String targetEventId,
    required String targetEventTitle,
    required DateTime startAt,
    DateTime? endAt,
    bool isDateOnly = false,
    String? timeZone,
    List<String> existingSpotIds = const <String>[],
    List<String> existingSpotListIds = const <String>[],
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    String? suggestedTitle,
    String? suggestedDescription,
    String? suggestedWebsiteUrl,
    bool? suggestedIsDateOnly,
    String? suggestedTimeZone,
    DateTime? suggestedStartAt,
    DateTime? suggestedEndAt,
    List<String>? suggestedSpotIds,
    double? suggestedLatitude,
    double? suggestedLongitude,
    String? suggestedAddress,
    String? suggestedCity,
    String? suggestedCountryCode,
    bool suggestedLocationRemoved = false,
    String? reporterUserId,
    String? reporterName,
    String? reporterEmail,
  }) async {
    return submitEventReport(
      title: targetEventTitle,
      startAt: startAt,
      endAt: endAt,
      isDateOnly: isDateOnly,
      timeZone: timeZone,
      spotIds: existingSpotIds,
      spotListIds: existingSpotListIds,
      latitude: latitude,
      longitude: longitude,
      address: address,
      city: city,
      countryCode: countryCode,
      targetEventId: targetEventId,
      targetEventTitle: targetEventTitle,
      reporterUserId: reporterUserId,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      suggestedTitle: suggestedTitle,
      suggestedDescription: suggestedDescription,
      suggestedWebsiteUrl: suggestedWebsiteUrl,
      suggestedIsDateOnly: suggestedIsDateOnly,
      suggestedTimeZone: suggestedTimeZone,
      suggestedStartAt: suggestedStartAt,
      suggestedEndAt: suggestedEndAt,
      suggestedSpotIds: suggestedSpotIds,
      suggestedLatitude: suggestedLatitude,
      suggestedLongitude: suggestedLongitude,
      suggestedAddress: suggestedAddress,
      suggestedCity: suggestedCity,
      suggestedCountryCode: suggestedCountryCode,
      suggestedLocationRemoved: suggestedLocationRemoved,
    );
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
    String? targetEventIdOverride,
  }) async {
    try {
      final reportRef = _firestore.collection('eventReports').doc(reportId);
      final snapshot = await reportRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final report = EventReport.fromSnapshot(snapshot);
      if (report.status == 'Approved' && report.approvedEventId != null) {
        return report.approvedEventId;
      }

      List<String>? promotedImageUrls;
      if (report.suggestedPhotoUrls.isNotEmpty) {
        promotedImageUrls = await _promoteSuggestedEventPhotos(
          report.suggestedPhotoUrls,
        );
        if (promotedImageUrls == null || promotedImageUrls.isEmpty) {
          debugPrint('Failed to promote suggested event photos');
          return null;
        }
      }

      final result = await _firestore.runTransaction<String?>((
        transaction,
      ) async {
        final txSnapshot = await transaction.get(reportRef);
        if (!txSnapshot.exists || txSnapshot.data() == null) {
          throw StateError('Event report not found');
        }

        final txReport = EventReport.fromSnapshot(txSnapshot);
        if (txReport.status == 'Approved' && txReport.approvedEventId != null) {
          return txReport.approvedEventId;
        }

        final txTargetEventId = txReport.targetEventId?.trim();
        final txIsSuggestionForExistingEvent =
            txTargetEventId != null && txTargetEventId.isNotEmpty;

        if (txIsSuggestionForExistingEvent) {
          final resolvedTargetEventId =
              targetEventIdOverride?.trim().isNotEmpty == true
              ? targetEventIdOverride!.trim()
              : txTargetEventId;
          final eventRef = _firestore
              .collection('events')
              .doc(resolvedTargetEventId);
          final eventSnapshot = await transaction.get(eventRef);
          if (!eventSnapshot.exists || eventSnapshot.data() == null) {
            throw StateError('Target event not found');
          }

          final eventData = eventSnapshot.data()!;
          if (!isNativeEventData(eventData)) {
            debugPrint(
              'Cannot approve event suggestion: target event '
              '$resolvedTargetEventId is from an external source',
            );
            return null;
          }

          final duplicateOf = eventData['duplicateOf'];
          if (duplicateOf is String && duplicateOf.trim().isNotEmpty) {
            debugPrint(
              'Cannot approve event suggestion: target event '
              '$resolvedTargetEventId is a duplicate',
            );
            return null;
          }

          final updates = _buildExistingEventSuggestionUpdate(
            report: txReport,
            existingEventData: eventData,
            promotedImageUrls: promotedImageUrls,
          );
          if (updates == null) {
            throw StateError('Invalid existing event suggestion payload');
          }

          if (updates.isNotEmpty) {
            updates['updatedAt'] = FieldValue.serverTimestamp();
            transaction.update(eventRef, updates);
          }

          transaction.update(reportRef, {
            'status': 'Approved',
            'approvedEventId': resolvedTargetEventId,
            'reviewedBy': approverUserId,
            if (approverName != null && approverName.trim().isNotEmpty)
              'reviewedByName': approverName.trim(),
            if (moderatorNotes != null && moderatorNotes.trim().isNotEmpty)
              'moderatorNotes': moderatorNotes.trim(),
            if (promotedImageUrls != null && promotedImageUrls.isNotEmpty)
              'suggestedPhotoUrls': <String>[],
            'reviewedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return resolvedTargetEventId;
        }

        final eventData = _buildEventData(
          report: txReport,
          approverUserId: approverUserId,
          imageUrls: promotedImageUrls,
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
          if (promotedImageUrls != null && promotedImageUrls.isNotEmpty)
            'suggestedPhotoUrls': <String>[],
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
      final reportRef = _firestore.collection('eventReports').doc(reportId);
      final snapshot = await reportRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return false;
      }

      final report = EventReport.fromSnapshot(snapshot);
      var rejectedUrls = const <String>[];
      if (report.suggestedPhotoUrls.isNotEmpty) {
        rejectedUrls = await _moveEventPhotosToRejected(
          report.suggestedPhotoUrls,
        );
      }

      await reportRef.update({
        'status': 'Rejected',
        'reviewedBy': reviewerUserId,
        if (reviewerName != null && reviewerName.trim().isNotEmpty)
          'reviewedByName': reviewerName.trim(),
        if (moderatorNotes != null && moderatorNotes.trim().isNotEmpty)
          'moderatorNotes': moderatorNotes.trim(),
        if (rejectedUrls.isNotEmpty) ...{
          'rejectedPhotoUrls': rejectedUrls,
          'suggestedPhotoUrls': <String>[],
        },
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error rejecting event report: $e');
      return false;
    }
  }

  Stream<List<EventReport>>? _eventReportsStream;
  Stream<int>? _newReportCountStream;
  List<EventReport>? _latestEventReports;

  /// Last loaded report list; used as [StreamBuilder.initialData].
  List<EventReport>? get latestEventReports => _latestEventReports;

  /// Count of reports with status [statuses.first] ("New"); used as [StreamBuilder.initialData].
  int get newReportCount =>
      _latestEventReports?.where((r) => r.status == statuses.first).length ?? 0;

  Stream<List<EventReport>> watchEventReports() {
    return _eventReportsStream ??= replayLatest(
      _firestore
          .collection('eventReports')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final reports = snapshot.docs
                .map((doc) => EventReport.fromSnapshot(doc))
                .toList(growable: false);
            return reports;
          }),
      onValue: (reports) => _latestEventReports = reports,
    );
  }

  /// Streams the number of event reports with status [statuses.first] ("New").
  Stream<int> watchNewReportCount() {
    return _newReportCountStream ??= replayLatest(
      watchEventReports().map(
        (reports) => reports.where((r) => r.status == statuses.first).length,
      ),
    );
  }

  /// Move staging photos from [eventSuggestions/] to [events/] with resize.
  Future<List<String>?> _promoteSuggestedEventPhotos(
    List<String> photoUrls,
  ) async {
    final finalPhotoUrls = <String>[];

    for (final photoUrl in photoUrls) {
      try {
        await Future<void>.delayed(Duration.zero);

        final filePath = _storagePathFromUrl(
          photoUrl,
          expectedPrefix: eventSuggestionsPrefix,
        );
        if (filePath == null) {
          debugPrint('Invalid event suggestion photo URL: $photoUrl');
          continue;
        }

        final suggestedPath = filePath.replaceFirst(
          eventSuggestionsPrefix,
          eventsPrefix,
        );
        final baseName = suggestedPath.split('.').first;
        final newPath = '$baseName.jpg';

        final sourceRef = _storage.ref().child(filePath);
        final destRef = _storage.ref().child(newPath);

        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          debugPrint(
            'Failed to fetch event suggestion photo: ${response.statusCode}',
          );
          continue;
        }

        final rawBytes = Uint8List.fromList(response.bodyBytes);
        await Future<void>.delayed(Duration.zero);
        final resizedBytes = resizeImageForSpotUpload(rawBytes);
        if (resizedBytes == null || resizedBytes.isEmpty) {
          debugPrint('Failed to resize event suggestion photo: $photoUrl');
          continue;
        }

        await destRef.putData(
          resizedBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final newUrl = await destRef.getDownloadURL();
        finalPhotoUrls.add(newUrl);
        await sourceRef.delete();
      } catch (e) {
        debugPrint('Error promoting event photo $photoUrl: $e');
      }
    }

    if (finalPhotoUrls.isEmpty) {
      return null;
    }
    return finalPhotoUrls;
  }

  @visibleForTesting
  static Map<String, dynamic>? buildExistingEventSuggestionUpdateForTest({
    required EventReport report,
    required Map<String, dynamic> existingEventData,
    List<String>? promotedImageUrls,
  }) {
    return _buildExistingEventSuggestionUpdate(
      report: report,
      existingEventData: existingEventData,
      promotedImageUrls: promotedImageUrls,
    );
  }

  static Map<String, dynamic>? _buildExistingEventSuggestionUpdate({
    required EventReport report,
    required Map<String, dynamic> existingEventData,
    List<String>? promotedImageUrls,
  }) {
    final updates = <String, dynamic>{};

    final suggestedTitle = report.suggestedTitle?.trim();
    if (suggestedTitle != null && suggestedTitle.isNotEmpty) {
      updates['title'] = suggestedTitle;
    }

    final suggestedDescription = report.suggestedDescription?.trim();
    if (suggestedDescription != null && suggestedDescription.isNotEmpty) {
      updates['description'] = suggestedDescription;
    }

    final suggestedWebsiteUrl = report.suggestedWebsiteUrl?.trim();
    if (suggestedWebsiteUrl != null && suggestedWebsiteUrl.isNotEmpty) {
      updates['websiteUrl'] = suggestedWebsiteUrl;
    }

    if (report.suggestedIsDateOnly != null) {
      updates['isDateOnly'] = report.suggestedIsDateOnly;
    }

    final suggestedTimeZone = report.suggestedTimeZone?.trim();
    if (suggestedTimeZone != null && suggestedTimeZone.isNotEmpty) {
      updates['timeZone'] = suggestedTimeZone;
    }

    if (report.suggestedStartAt != null) {
      updates['startAt'] = Timestamp.fromDate(report.suggestedStartAt!.toUtc());
    }

    if (report.suggestedEndAt != null) {
      final effectiveStartAt = (updates['startAt'] is Timestamp)
          ? (updates['startAt'] as Timestamp).toDate()
          : (existingEventData['startAt'] is Timestamp)
          ? (existingEventData['startAt'] as Timestamp).toDate()
          : null;
      final suggestedEndAt = report.suggestedEndAt!.toUtc();
      if (effectiveStartAt != null &&
          suggestedEndAt.isBefore(effectiveStartAt)) {
        debugPrint('Suggested event end time is before start time');
        return null;
      }
      updates['endAt'] = Timestamp.fromDate(suggestedEndAt);
    }

    if (report.suggestedSpotIds != null) {
      updates['spotIds'] =
          report.suggestedSpotIds!
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort();
    }

    if (report.suggestedLocationRemoved) {
      updates['latitude'] = FieldValue.delete();
      updates['longitude'] = FieldValue.delete();
      updates['address'] = FieldValue.delete();
      updates['city'] = FieldValue.delete();
      updates['countryCode'] = FieldValue.delete();
    } else if (report.suggestedLatitude != null &&
        report.suggestedLongitude != null) {
      updates['latitude'] = report.suggestedLatitude;
      updates['longitude'] = report.suggestedLongitude;
      final address = report.suggestedAddress?.trim();
      final city = report.suggestedCity?.trim();
      final countryCode = report.suggestedCountryCode?.trim().toUpperCase();
      updates['address'] = address?.isNotEmpty == true
          ? address
          : FieldValue.delete();
      updates['city'] = city?.isNotEmpty == true ? city : FieldValue.delete();
      updates['countryCode'] = countryCode?.isNotEmpty == true
          ? countryCode
          : FieldValue.delete();
    }

    final effectiveStartAt = (updates['startAt'] is Timestamp)
        ? (updates['startAt'] as Timestamp).toDate()
        : (existingEventData['startAt'] is Timestamp)
        ? (existingEventData['startAt'] as Timestamp).toDate()
        : null;
    final effectiveEndAt = (updates['endAt'] is Timestamp)
        ? (updates['endAt'] as Timestamp).toDate()
        : (existingEventData['endAt'] is Timestamp)
        ? (existingEventData['endAt'] as Timestamp).toDate()
        : null;
    if (effectiveStartAt != null &&
        effectiveEndAt != null &&
        effectiveEndAt.isBefore(effectiveStartAt)) {
      debugPrint(
        'Existing event end time would become invalid after suggestion',
      );
      return null;
    }

    if (promotedImageUrls != null && promotedImageUrls.isNotEmpty) {
      final existingImageUrls = (existingEventData['imageUrls'] is Iterable)
          ? (existingEventData['imageUrls'] as Iterable)
                .whereType<String>()
                .where((url) => url.trim().isNotEmpty)
                .toList(growable: true)
          : <String>[];
      for (final url in promotedImageUrls) {
        if (!existingImageUrls.contains(url)) {
          existingImageUrls.add(url);
        }
      }
      if (existingImageUrls.length > maxSuggestedPhotos) {
        debugPrint(
          'Existing event already has too many photos (${existingImageUrls.length})',
        );
        return null;
      }
      updates['imageUrls'] = existingImageUrls;
    }

    final reporterUserId = report.reporterUserId?.trim();
    final reporterUserName = report.reporterName?.trim();
    if (reporterUserId != null && reporterUserId.isNotEmpty) {
      final contributors = (existingEventData['contributors'] is Iterable)
          ? (existingEventData['contributors'] as Iterable)
                .whereType<Map>()
                .map((e) => Map<String, String>.from(e))
                .toList(growable: true)
          : <Map<String, String>>[];
      final exists = contributors.any((c) => c['userId'] == reporterUserId);
      if (!exists) {
        final contributorName =
            (reporterUserName != null && reporterUserName.isNotEmpty)
            ? reporterUserName
            : reporterUserId;
        contributors.add(<String, String>{
          'userId': reporterUserId,
          'userName': contributorName,
        });
      }
      updates['contributors'] = contributors;
    }

    return updates;
  }

  Future<List<String>> _moveEventPhotosToRejected(
    List<String> photoUrls,
  ) async {
    final rejectedUrls = <String>[];

    for (final photoUrl in photoUrls) {
      try {
        final filePath = _storagePathFromUrl(
          photoUrl,
          expectedPrefix: eventSuggestionsPrefix,
        );
        if (filePath == null) continue;

        final newPath = filePath.replaceFirst(
          eventSuggestionsPrefix,
          eventRejectedPrefix,
        );
        final sourceRef = _storage.ref().child(filePath);
        final destRef = _storage.ref().child(newPath);

        final data = await sourceRef.getData();
        if (data != null) {
          final metadata = await sourceRef.getMetadata();
          final contentType = metadata.contentType ?? 'image/jpeg';

          await destRef.putData(
            data,
            SettableMetadata(contentType: contentType),
          );
          rejectedUrls.add(await destRef.getDownloadURL());
          await sourceRef.delete();
        }
      } catch (e) {
        debugPrint('Error moving event photo to rejected $photoUrl: $e');
      }
    }

    return rejectedUrls;
  }

  String? _storagePathFromUrl(
    String photoUrl, {
    required String expectedPrefix,
  }) {
    try {
      final uri = Uri.parse(photoUrl);
      String? filePath;

      if (uri.pathSegments.contains('o')) {
        final oIndex = uri.pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < uri.pathSegments.length) {
          filePath = Uri.decodeComponent(uri.pathSegments[oIndex + 1]);
        }
      } else if (uri.host.contains('storage.googleapis.com')) {
        final prefixSegment = expectedPrefix.replaceAll('/', '');
        final pathIndex = uri.pathSegments.indexOf(prefixSegment);
        if (pathIndex != -1) {
          filePath = uri.pathSegments.sublist(pathIndex).join('/');
        }
      }

      if (filePath != null && filePath.startsWith(expectedPrefix)) {
        return filePath;
      }
    } catch (e) {
      debugPrint('Error parsing storage path from URL: $e');
    }
    return null;
  }

  String _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
  }

  Map<String, dynamic>? _buildEventData({
    required EventReport report,
    required String approverUserId,
    List<String>? imageUrls,
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
    final normalizedImageUrls = imageUrls
        ?.map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .take(maxSuggestedPhotos)
        .toList();
    final createdBy = resolveEventCreatedBy(
      reporterUserId: report.reporterUserId,
      approverUserId: approverUserId,
    );

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
      if (normalizedImageUrls != null && normalizedImageUrls.isNotEmpty)
        'imageUrls': normalizedImageUrls,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @visibleForTesting
  static String resolveEventCreatedBy({
    String? reporterUserId,
    required String approverUserId,
  }) {
    final normalizedReporterId = reporterUserId?.trim();
    if (normalizedReporterId != null && normalizedReporterId.isNotEmpty) {
      return normalizedReporterId;
    }
    return approverUserId;
  }
}
