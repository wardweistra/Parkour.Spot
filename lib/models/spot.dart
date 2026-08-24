import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String? id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? countryCode;
  final List<String>? imageUrls;
  bool get hasImages => imageUrls?.isNotEmpty ?? false;
  final List<String>? youtubeVideoIds;
  final String? folderName;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? externalSyncLastSeenAt;
  final DateTime? externalSyncLastChangedAt;
  final String? spotSource;
  final String? spotSourceName;
  final bool spotSourceRemoved;
  final DateTime? spotSourceRemovedAt;
  final double? averageRating;
  final int? ratingCount;
  final double? wilsonLowerBound;
  final double? ranking;
  final String? spotAccess;
  final List<String>? spotFeatures;
  final Map<String, String>? spotFacilities;
  final List<String>? goodFor;
  final String? duplicateOf; // ID of the original spot if this is a duplicate
  /// Whether transferable fields changed after this spot was marked duplicate.
  final bool duplicateHasPendingChanges;

  /// Transferable field groups that differ from the last-reviewed baseline.
  final List<String> duplicateChangedFields;
  final bool hidden; // Whether the spot is hidden from public view
  final List<Map<String, String>>?
  contributors; // List of contributors who improved the spot
  final bool
  createdFromCreateNative; // Whether spot was created via "Create Native"

  static const Object _unset = Object();

  /// Whether this spot is marked as a duplicate of another spot.
  bool get isDuplicate {
    final originalId = duplicateOf?.trim();
    return originalId != null && originalId.isNotEmpty;
  }

  /// Whether staff should review post-link changes on this duplicate.
  bool get hasDuplicatePendingChanges =>
      isDuplicate && duplicateHasPendingChanges;

  Spot({
    this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.countryCode,
    this.imageUrls,
    this.youtubeVideoIds,
    this.folderName,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.externalSyncLastSeenAt,
    this.externalSyncLastChangedAt,
    this.spotSource,
    this.spotSourceName,
    this.spotSourceRemoved = false,
    this.spotSourceRemovedAt,
    this.averageRating,
    this.ratingCount,
    this.wilsonLowerBound,
    this.ranking,
    this.spotAccess,
    this.spotFeatures,
    this.spotFacilities,
    this.goodFor,
    this.duplicateOf,
    this.duplicateHasPendingChanges = false,
    this.duplicateChangedFields = const <String>[],
    this.hidden = false,
    this.contributors,
    this.createdFromCreateNative = false,
  });

  factory Spot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String? extractYoutubeId(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;
      // If it's already a likely ID, return as-is (11 chars typical)
      if (RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(trimmed) &&
          !trimmed.contains('/')) {
        return trimmed;
      }
      try {
        final uri = Uri.parse(trimmed);
        // youtu.be/<id>
        if (uri.host.contains('youtu.be')) {
          final seg = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : null;
          if (seg != null && seg.isNotEmpty) return seg;
        }
        // youtube.com/watch?v=<id>
        final vParam = uri.queryParameters['v'];
        if (vParam != null && vParam.isNotEmpty) return vParam;
        // youtube.com/embed/<id>
        final embedIndex = uri.pathSegments.indexOf('embed');
        if (embedIndex != -1 && embedIndex + 1 < uri.pathSegments.length) {
          return uri.pathSegments[embedIndex + 1];
        }
        // youtube.com/shorts/<id>
        final shortsIndex = uri.pathSegments.indexOf('shorts');
        if (shortsIndex != -1 && shortsIndex + 1 < uri.pathSegments.length) {
          return uri.pathSegments[shortsIndex + 1];
        }
      } catch (_) {}
      return trimmed; // Fallback to raw value
    }

    List<String>? extractYoutubeIdsList(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value
            .whereType<dynamic>()
            .map((e) => e.toString())
            .map((s) => extractYoutubeId(s))
            .whereType<String>()
            .toList();
      }
      if (value is String) {
        final id = extractYoutubeId(value);
        return id == null ? null : <String>[id];
      }
      return null;
    }

    return Spot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      address: data['address'],
      city: data['city'],
      countryCode: data['countryCode'],
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl']] : null),
      youtubeVideoIds: extractYoutubeIdsList(data['youtubeVideoIds']),
      folderName: data['folderName'],
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      externalSyncLastSeenAt: data['externalSyncLastSeenAt'] is Timestamp
          ? (data['externalSyncLastSeenAt'] as Timestamp).toDate()
          : null,
      externalSyncLastChangedAt: data['externalSyncLastChangedAt'] is Timestamp
          ? (data['externalSyncLastChangedAt'] as Timestamp).toDate()
          : null,
      spotSource: data['spotSource'],
      spotSourceName: data['spotSourceName'],
      spotSourceRemoved: data['spotSourceRemoved'] == true,
      spotSourceRemovedAt: data['spotSourceRemovedAt'] is Timestamp
          ? (data['spotSourceRemovedAt'] as Timestamp).toDate()
          : null,
      averageRating: data['averageRating'] != null
          ? (data['averageRating'] as num).toDouble()
          : null,
      ratingCount: data['ratingCount'],
      wilsonLowerBound: data['wilsonLowerBound'] != null
          ? (data['wilsonLowerBound'] as num).toDouble()
          : null,
      ranking: data['ranking'] != null
          ? (data['ranking'] as num).toDouble()
          : null,
      spotAccess: data['spotAccess'],
      spotFeatures: data['spotFeatures'] != null
          ? List<String>.from(data['spotFeatures'])
          : null,
      spotFacilities: data['spotFacilities'] != null
          ? Map<String, String>.from(data['spotFacilities'])
          : null,
      goodFor: data['goodFor'] != null
          ? List<String>.from(data['goodFor'])
          : null,
      duplicateOf: data['duplicateOf'],
      duplicateHasPendingChanges: data['duplicateHasPendingChanges'] == true,
      duplicateChangedFields: data['duplicateChangedFields'] is List
          ? (data['duplicateChangedFields'] as List)
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const <String>[],
      hidden: data['hidden'] == true,
      contributors: data['contributors'] != null
          ? (data['contributors'] as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
          : null,
      createdFromCreateNative: data['createdFromCreateNative'] == true,
    );
  }

  factory Spot.fromMap(Map<String, dynamic> data) {
    String? extractYoutubeId(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;
      if (RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(trimmed) &&
          !trimmed.contains('/')) {
        return trimmed;
      }
      try {
        final uri = Uri.parse(trimmed);
        if (uri.host.contains('youtu.be')) {
          final seg = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : null;
          if (seg != null && seg.isNotEmpty) return seg;
        }
        final vParam = uri.queryParameters['v'];
        if (vParam != null && vParam.isNotEmpty) return vParam;
        final embedIndex = uri.pathSegments.indexOf('embed');
        if (embedIndex != -1 && embedIndex + 1 < uri.pathSegments.length) {
          return uri.pathSegments[embedIndex + 1];
        }
        final shortsIndex = uri.pathSegments.indexOf('shorts');
        if (shortsIndex != -1 && shortsIndex + 1 < uri.pathSegments.length) {
          return uri.pathSegments[shortsIndex + 1];
        }
      } catch (_) {}
      return trimmed;
    }

    List<String>? extractYoutubeIdsList(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value
            .whereType<dynamic>()
            .map((e) => e.toString())
            .map((s) => extractYoutubeId(s))
            .whereType<String>()
            .toList();
      }
      if (value is String) {
        final id = extractYoutubeId(value);
        return id == null ? null : <String>[id];
      }
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        try {
          return DateTime.tryParse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return Spot(
      id: data['id'] as String?,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      address: data['address'] as String?,
      city: data['city'] as String?,
      countryCode: data['countryCode'] as String?,
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl'] as String] : null),
      youtubeVideoIds: extractYoutubeIdsList(data['youtubeVideoIds']),
      folderName: data['folderName'] as String?,
      createdBy: data['createdBy'] as String?,
      createdByName: data['createdByName'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      externalSyncLastSeenAt: parseDate(data['externalSyncLastSeenAt']),
      externalSyncLastChangedAt: parseDate(data['externalSyncLastChangedAt']),
      spotSource: data['spotSource'] as String?,
      spotSourceName: data['spotSourceName'] as String?,
      spotSourceRemoved: data['spotSourceRemoved'] == true,
      spotSourceRemovedAt: parseDate(data['spotSourceRemovedAt']),
      averageRating: (data['averageRating'] as num?)?.toDouble(),
      ratingCount: (data['ratingCount'] is int)
          ? data['ratingCount'] as int
          : (data['ratingCount'] as num?)?.toInt(),
      wilsonLowerBound: (data['wilsonLowerBound'] as num?)?.toDouble(),
      ranking: (data['ranking'] as num?)?.toDouble(),
      spotAccess: data['spotAccess'] as String?,
      spotFeatures: data['spotFeatures'] is List
          ? List<String>.from(data['spotFeatures'])
          : null,
      spotFacilities: data['spotFacilities'] is Map
          ? Map<String, String>.from(data['spotFacilities'])
          : null,
      goodFor: data['goodFor'] is List
          ? List<String>.from(data['goodFor'])
          : null,
      duplicateOf: data['duplicateOf'] as String?,
      duplicateHasPendingChanges: data['duplicateHasPendingChanges'] == true,
      duplicateChangedFields: data['duplicateChangedFields'] is List
          ? (data['duplicateChangedFields'] as List)
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const <String>[],
      hidden: data['hidden'] == true,
      contributors: data['contributors'] is List
          ? (data['contributors'] as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
          : null,
      createdFromCreateNative: data['createdFromCreateNative'] == true,
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'countryCode': countryCode,
      'imageUrls': imageUrls,
      'hasImages': hasImages,
      if (youtubeVideoIds != null)
        'youtubeVideoIds': (youtubeVideoIds!.isEmpty && isUpdate)
            ? FieldValue.delete()
            : (youtubeVideoIds!.isEmpty ? null : youtubeVideoIds),
      'folderName': folderName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (externalSyncLastSeenAt != null)
        'externalSyncLastSeenAt': externalSyncLastSeenAt,
      if (externalSyncLastChangedAt != null)
        'externalSyncLastChangedAt': externalSyncLastChangedAt,
      'spotSource': spotSource,
      'spotSourceName': spotSourceName,
      'spotSourceRemoved': spotSourceRemoved,
      if (spotSourceRemovedAt != null)
        'spotSourceRemovedAt': spotSourceRemovedAt,
      if (averageRating != null) 'averageRating': averageRating,
      if (ratingCount != null) 'ratingCount': ratingCount,
      if (wilsonLowerBound != null) 'wilsonLowerBound': wilsonLowerBound,
      if (ranking != null) 'ranking': ranking,
      if (spotAccess != null) 'spotAccess': spotAccess,
      if (spotFeatures != null) 'spotFeatures': spotFeatures,
      if (spotFacilities != null) 'spotFacilities': spotFacilities,
      if (goodFor != null) 'goodFor': goodFor,
      'duplicateOf': duplicateOf,
      'hidden': hidden,
      if (contributors != null) 'contributors': contributors,
      'createdFromCreateNative': createdFromCreateNative,
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    List<String>? imageUrls,
    Object? youtubeVideoIds = _unset,
    String? folderName,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? externalSyncLastSeenAt = _unset,
    Object? externalSyncLastChangedAt = _unset,
    String? spotSource,
    String? spotSourceName,
    bool? spotSourceRemoved,
    Object? spotSourceRemovedAt = _unset,
    double? averageRating,
    int? ratingCount,
    double? wilsonLowerBound,
    double? ranking,
    String? spotAccess,
    List<String>? spotFeatures,
    Map<String, String>? spotFacilities,
    List<String>? goodFor,
    Object? duplicateOf = _unset,
    bool? duplicateHasPendingChanges,
    List<String>? duplicateChangedFields,
    bool? hidden,
    List<Map<String, String>>? contributors,
    bool? createdFromCreateNative,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      imageUrls: imageUrls ?? this.imageUrls,
      youtubeVideoIds: identical(youtubeVideoIds, _unset)
          ? this.youtubeVideoIds
          : youtubeVideoIds as List<String>?,
      folderName: folderName ?? this.folderName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      externalSyncLastSeenAt: identical(externalSyncLastSeenAt, _unset)
          ? this.externalSyncLastSeenAt
          : externalSyncLastSeenAt as DateTime?,
      externalSyncLastChangedAt: identical(externalSyncLastChangedAt, _unset)
          ? this.externalSyncLastChangedAt
          : externalSyncLastChangedAt as DateTime?,
      spotSource: spotSource ?? this.spotSource,
      spotSourceName: spotSourceName ?? this.spotSourceName,
      spotSourceRemoved: spotSourceRemoved ?? this.spotSourceRemoved,
      spotSourceRemovedAt: identical(spotSourceRemovedAt, _unset)
          ? this.spotSourceRemovedAt
          : spotSourceRemovedAt as DateTime?,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      wilsonLowerBound: wilsonLowerBound ?? this.wilsonLowerBound,
      ranking: ranking ?? this.ranking,
      spotAccess: spotAccess ?? this.spotAccess,
      spotFeatures: spotFeatures ?? this.spotFeatures,
      spotFacilities: spotFacilities ?? this.spotFacilities,
      goodFor: goodFor ?? this.goodFor,
      duplicateOf: identical(duplicateOf, _unset)
          ? this.duplicateOf
          : duplicateOf as String?,
      duplicateHasPendingChanges:
          duplicateHasPendingChanges ?? this.duplicateHasPendingChanges,
      duplicateChangedFields:
          duplicateChangedFields ?? this.duplicateChangedFields,
      hidden: hidden ?? this.hidden,
      contributors: contributors ?? this.contributors,
      createdFromCreateNative:
          createdFromCreateNative ?? this.createdFromCreateNative,
    );
  }

  @override
  String toString() {
    return 'Spot(id: $id, name: $name, description: $description, lat: $latitude, lng: $longitude)';
  }
}
