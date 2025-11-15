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
    this.reporterEmail,
    this.spotCountryCode,
    this.spotCity,
    this.duplicateOfSpotId,
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

  /// Reporter e-mail when authenticated.
  final String? reporterEmail;

  /// ISO country code of the spot when available.
  final String? spotCountryCode;

  /// City of the spot when available.
  final String? spotCity;

  /// ID of the spot this is a duplicate of (when category is "Duplicate spot").
  final String? duplicateOfSpotId;

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

    return SpotReport(
      id: snapshot.id,
      spotId: data['spotId'] as String? ?? '',
      spotName: data['spotName'] as String? ?? 'Unknown spot',
      categories: parseCategories(data['categories']),
      otherCategory: data['otherCategory'] as String?,
      details: data['details'] as String?,
      contactEmail: data['contactEmail'] as String?,
      reporterUserId: data['reporterUserId'] as String?,
      reporterEmail: data['reporterEmail'] as String?,
      spotCountryCode: data['spotCountryCode'] as String?,
      spotCity: data['spotCity'] as String?,
      duplicateOfSpotId: data['duplicateOfSpotId'] as String?,
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
