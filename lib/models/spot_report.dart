import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Immutable representation of a spot report submitted by end users.
@immutable
class SpotReport {
  const SpotReport({
    required this.id,
    required this.spotId,
    required this.spotName,
    required this.categories,
    required this.status,
    this.otherCategory,
    this.details,
    this.contactEmail,
    this.reporterUserId,
    this.reporterName,
    this.reporterEmail,
    this.spotCountryCode,
    this.spotCity,
    this.duplicateOfSpotId,
    this.suggestedPhotoUrls,
    this.acceptedPhotoUrls,
    this.rejectedPhotoUrls,
    this.suggestedName,
    this.suggestedDescription,
    this.suggestedLatitude,
    this.suggestedLongitude,
    this.suggestedGoodFor,
    this.suggestedSpotFeatures,
    this.suggestedSpotAccess,
    this.suggestedSpotFacilities,
    this.acceptedEditFields,
    this.rejectedEditFields,
    this.moderatorNotes,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore document identifier.
  final String id;

  /// Identifier of the reported spot.
  final String spotId;

  /// Friendly name of the reported spot.
  final String spotName;

  /// Selected report categories.
  final List<String> categories;

  /// Optional free-form category provided by the reporter.
  final String? otherCategory;

  /// Additional notes supplied by the reporter.
  final String? details;

  /// Optional contact e-mail from the reporter.
  final String? contactEmail;

  /// Reporter user id when authenticated.
  final String? reporterUserId;

  /// Reporter display name when authenticated.
  final String? reporterName;

  /// Reporter e-mail when authenticated.
  final String? reporterEmail;

  /// ISO country code of the spot when available.
  final String? spotCountryCode;

  /// City of the spot when available.
  final String? spotCity;

  /// ID of the spot this is a duplicate of (when category is "Duplicate spot").
  final String? duplicateOfSpotId;

  /// URLs of photos suggested by the user (when category is "Photo suggestion").
  final List<String>? suggestedPhotoUrls;

  /// URLs of photos that were accepted/approved (moved to /spots/ folder).
  final List<String>? acceptedPhotoUrls;

  /// URLs of photos that were rejected (moved to /rejected/ folder).
  final List<String>? rejectedPhotoUrls;

  /// Proposed title (when category is "Edit suggestion").
  final String? suggestedName;

  /// Proposed description (when category is "Edit suggestion").
  final String? suggestedDescription;

  /// Proposed latitude (when category is "Edit suggestion").
  final double? suggestedLatitude;

  /// Proposed longitude (when category is "Edit suggestion").
  final double? suggestedLongitude;

  /// Proposed good-for skills (when category is "Edit suggestion").
  final List<String>? suggestedGoodFor;

  /// Proposed physical features (when category is "Edit suggestion").
  final List<String>? suggestedSpotFeatures;

  /// Proposed access type (when category is "Edit suggestion").
  final String? suggestedSpotAccess;

  /// Proposed facilities (when category is "Edit suggestion").
  final Map<String, String>? suggestedSpotFacilities;

  /// Fields moderator accepted (e.g. ["name", "description"]).
  final List<String>? acceptedEditFields;

  /// Fields moderator rejected.
  final List<String>? rejectedEditFields;

  /// Moderator comment documenting why they accepted or rejected suggestions.
  final String? moderatorNotes;

  /// Current moderation status of the report.
  final String status;

  /// Firestore server timestamp indicating when report was created.
  final DateTime? createdAt;

  /// Firestore server timestamp indicating when report was last updated.
  final DateTime? updatedAt;

  /// Factory helper to create a [SpotReport] from a Firestore document snapshot.
  factory SpotReport.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Missing data for spot report ${snapshot.id}');
    }

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    List<String> parseCategories(dynamic raw) {
      if (raw is Iterable) {
        return raw.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    List<String>? parsePhotoUrls(dynamic raw) {
      if (raw == null) return null;
      if (raw is Iterable) {
        return raw.whereType<String>().toList(growable: false);
      }
      return null;
    }

    List<String>? parseStringList(dynamic raw) {
      if (raw == null) return null;
      if (raw is Iterable) {
        return raw.whereType<String>().toList(growable: false);
      }
      return null;
    }

    Map<String, String>? parseStringMap(dynamic raw) {
      if (raw == null || raw is! Map) return null;
      final result = <String, String>{};
      for (final entry in raw.entries) {
        if (entry.key != null && entry.value != null) {
          result[entry.key.toString()] = entry.value.toString();
        }
      }
      return result.isEmpty ? null : result;
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      return null;
    }

    return SpotReport(
      id: snapshot.id,
      spotId: data['spotId'] as String? ?? '',
      spotName: data['spotName'] as String? ?? 'Unknown spot',
      categories: parseCategories(data['categories']),
      otherCategory: data['otherCategory'] as String?,
      details: data['details'] as String?,
      contactEmail: data['contactEmail'] as String?,
      reporterUserId: data['reporterUserId'] as String?,
      reporterName: data['reporterName'] as String?,
      reporterEmail: data['reporterEmail'] as String?,
      spotCountryCode: data['spotCountryCode'] as String?,
      spotCity: data['spotCity'] as String?,
      duplicateOfSpotId: data['duplicateOfSpotId'] as String?,
      suggestedPhotoUrls: parsePhotoUrls(data['suggestedPhotoUrls']),
      acceptedPhotoUrls: parsePhotoUrls(data['acceptedPhotoUrls']),
      rejectedPhotoUrls: parsePhotoUrls(data['rejectedPhotoUrls']),
      suggestedName: data['suggestedName'] as String?,
      suggestedDescription: data['suggestedDescription'] as String?,
      suggestedLatitude: parseDouble(data['suggestedLatitude']),
      suggestedLongitude: parseDouble(data['suggestedLongitude']),
      suggestedGoodFor: parseStringList(data['suggestedGoodFor']),
      suggestedSpotFeatures: parseStringList(data['suggestedSpotFeatures']),
      suggestedSpotAccess: data['suggestedSpotAccess'] as String?,
      suggestedSpotFacilities: parseStringMap(data['suggestedSpotFacilities']),
      acceptedEditFields: parseStringList(data['acceptedEditFields']),
      rejectedEditFields: parseStringList(data['rejectedEditFields']),
      moderatorNotes: data['moderatorNotes'] as String?,
      status: data['status'] as String? ?? 'New',
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  /// Convenience method with defensive copying for categories.
  List<String> get displayCategories =>
      List<String>.unmodifiable(<String>[...categories, if (otherCategory?.isNotEmpty == true) otherCategory!]);

  /// Primary contact address to reach the reporter, when available.
  String? get primaryContact => contactEmail?.isNotEmpty == true
      ? contactEmail
      : reporterEmail?.isNotEmpty == true
          ? reporterEmail
          : null;

  /// Whether this report contains edit suggestions (location, name, description, or attributes).
  bool get hasEditSuggestions =>
      suggestedName != null ||
      suggestedDescription != null ||
      (suggestedLatitude != null && suggestedLongitude != null) ||
      (suggestedGoodFor != null && suggestedGoodFor!.isNotEmpty) ||
      (suggestedSpotFeatures != null && suggestedSpotFeatures!.isNotEmpty) ||
      suggestedSpotAccess != null ||
      (suggestedSpotFacilities != null && suggestedSpotFacilities!.isNotEmpty);

  /// Human readable location string when city/country are available.
  String? get locationSummary {
    if ((spotCity?.isNotEmpty ?? false) && (spotCountryCode?.isNotEmpty ?? false)) {
      return '${spotCity!}, ${spotCountryCode!.toUpperCase()}';
    }
    if (spotCity?.isNotEmpty ?? false) {
      return spotCity;
    }
    if (spotCountryCode?.isNotEmpty ?? false) {
      return spotCountryCode!.toUpperCase();
    }
    return null;
  }
}
