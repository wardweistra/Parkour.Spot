import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class EventReport {
  const EventReport({
    required this.id,
    required this.title,
    required this.status,
    required this.startAt,
    this.description,
    this.websiteUrl,
    this.endAt,
    this.isDateOnly = false,
    this.timeZone,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.countryCode,
    this.spotIds = const <String>[],
    this.spotListIds = const <String>[],
    this.linkedSpotName,
    this.linkedSpotListName,
    this.targetEventId,
    this.targetEventTitle,
    this.reporterUserId,
    this.reporterName,
    this.reporterEmail,
    this.moderatorNotes,
    this.approvedEventId,
    this.reviewedBy,
    this.reviewedByName,
    this.suggestedTitle,
    this.suggestedDescription,
    this.suggestedWebsiteUrl,
    this.suggestedIsDateOnly,
    this.suggestedTimeZone,
    this.suggestedStartAt,
    this.suggestedEndAt,
    this.suggestedPhotoUrls = const <String>[],
    this.rejectedPhotoUrls = const <String>[],
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? websiteUrl;
  final DateTime startAt;
  final DateTime? endAt;
  final bool isDateOnly;
  final String? timeZone;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? countryCode;
  final List<String> spotIds;
  final List<String> spotListIds;
  final String? linkedSpotName;
  final String? linkedSpotListName;
  final String? targetEventId;
  final String? targetEventTitle;
  final String? reporterUserId;
  final String? reporterName;
  final String? reporterEmail;
  final String status;
  final String? moderatorNotes;
  final String? approvedEventId;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? suggestedTitle;
  final String? suggestedDescription;
  final String? suggestedWebsiteUrl;
  final bool? suggestedIsDateOnly;
  final String? suggestedTimeZone;
  final DateTime? suggestedStartAt;
  final DateTime? suggestedEndAt;
  final List<String> suggestedPhotoUrls;
  final List<String> rejectedPhotoUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  factory EventReport.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Missing data for event report ${snapshot.id}');
    }

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is Iterable) {
        return raw.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    double? parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return null;
    }

    final parsedStart = parseDate(data['startAt']);

    return EventReport(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Untitled event',
      description: data['description'] as String?,
      websiteUrl: data['websiteUrl'] as String?,
      startAt: parsedStart ?? DateTime.now().toUtc(),
      endAt: parseDate(data['endAt']),
      isDateOnly: data['isDateOnly'] == true,
      timeZone: data['timeZone'] as String?,
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),
      address: data['address'] as String?,
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
      spotIds: parseStringList(data['spotIds']),
      spotListIds: parseStringList(data['spotListIds']),
      linkedSpotName: data['linkedSpotName'] as String?,
      linkedSpotListName: data['linkedSpotListName'] as String?,
      targetEventId: data['targetEventId'] as String?,
      targetEventTitle: data['targetEventTitle'] as String?,
      reporterUserId: data['reporterUserId'] as String?,
      reporterName: data['reporterName'] as String?,
      reporterEmail: data['reporterEmail'] as String?,
      status: data['status'] as String? ?? 'New',
      moderatorNotes: data['moderatorNotes'] as String?,
      approvedEventId: data['approvedEventId'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedByName: data['reviewedByName'] as String?,
      suggestedTitle: data['suggestedTitle'] as String?,
      suggestedDescription: data['suggestedDescription'] as String?,
      suggestedWebsiteUrl: data['suggestedWebsiteUrl'] as String?,
      suggestedIsDateOnly: data['suggestedIsDateOnly'] is bool
          ? data['suggestedIsDateOnly'] as bool
          : null,
      suggestedTimeZone: data['suggestedTimeZone'] as String?,
      suggestedStartAt: parseDate(data['suggestedStartAt']),
      suggestedEndAt: parseDate(data['suggestedEndAt']),
      suggestedPhotoUrls: parseStringList(data['suggestedPhotoUrls']),
      rejectedPhotoUrls: parseStringList(data['rejectedPhotoUrls']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      reviewedAt: parseDate(data['reviewedAt']),
    );
  }

  bool get isSuggestionForExistingEvent {
    final id = targetEventId?.trim();
    return id != null && id.isNotEmpty;
  }

  bool get hasSuggestedEdits {
    return (suggestedTitle?.trim().isNotEmpty ?? false) ||
        (suggestedDescription?.trim().isNotEmpty ?? false) ||
        (suggestedWebsiteUrl?.trim().isNotEmpty ?? false) ||
        suggestedIsDateOnly != null ||
        (suggestedTimeZone?.trim().isNotEmpty ?? false) ||
        suggestedStartAt != null ||
        suggestedEndAt != null;
  }

  String? get locationSummary {
    if ((city?.isNotEmpty ?? false) && (countryCode?.isNotEmpty ?? false)) {
      return '$city, ${countryCode!.toUpperCase()}';
    }
    if (city?.isNotEmpty ?? false) return city;
    if (countryCode?.isNotEmpty ?? false) return countryCode!.toUpperCase();
    if (address?.isNotEmpty ?? false) return address;
    return null;
  }
}
