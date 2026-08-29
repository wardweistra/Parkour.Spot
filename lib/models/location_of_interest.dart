import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationOfInterestKind { lastKnown, saved }

class LocationOfInterest {
  static const int defaultAlertRadiusKm = 50;
  static const List<int> allowedAlertRadiusKm = [10, 50, 100];

  /// 10, 50, or 100. Missing or invalid values become [defaultAlertRadiusKm].
  static int normalizeAlertRadiusKm(Object? value) {
    if (value is int && allowedAlertRadiusKm.contains(value)) {
      return value;
    }
    if (value is num) {
      final asInt = value.round();
      if (allowedAlertRadiusKm.contains(asInt)) {
        return asInt;
      }
    }
    return defaultAlertRadiusKm;
  }

  const LocationOfInterest({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.kind,
    required this.enabled,
    this.alertRadiusKm = defaultAlertRadiusKm,
    this.label,
    this.address,
    this.updatedAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final LocationOfInterestKind kind;
  final bool enabled;
  final int alertRadiusKm;
  final String? label;

  /// Reverse-geocoded formatted address for display (optional).
  final String? address;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isLastKnown => kind == LocationOfInterestKind.lastKnown;

  /// Stable Settings order: last-known first, then saved locations by
  /// created time (newest first). Toggling alerts must not reshuffle.
  static int compareForDisplay(LocationOfInterest a, LocationOfInterest b) {
    if (a.kind != b.kind) {
      if (a.kind == LocationOfInterestKind.lastKnown) return -1;
      if (b.kind == LocationOfInterestKind.lastKnown) return 1;
    }
    final aAt =
        a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bAt =
        b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byCreated = bAt.compareTo(aAt);
    if (byCreated != 0) return byCreated;
    return a.id.compareTo(b.id);
  }

  factory LocationOfInterest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LocationOfInterest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      kind: _kindFromString(data['kind'] as String?),
      enabled: data['enabled'] as bool? ?? true,
      alertRadiusKm: normalizeAlertRadiusKm(data['alertRadiusKm']),
      label: data['label'] as String?,
      address: data['address'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'kind': kind.name,
      'enabled': enabled,
      'alertRadiusKm': alertRadiusKm,
      'label': label,
      'address': address,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
    };
  }

  static LocationOfInterestKind _kindFromString(String? value) {
    switch (value) {
      case 'saved':
        return LocationOfInterestKind.saved;
      case 'lastKnown':
      default:
        return LocationOfInterestKind.lastKnown;
    }
  }
}
