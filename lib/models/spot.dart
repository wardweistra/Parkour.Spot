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
  final List<String>? youtubeVideoIds;
  final String? folderName;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? tags;
  final bool? isPublic;
  final String? spotSource;
  final String? spotSourceName;
  final double? averageRating;
  final int? ratingCount;
  final double? wilsonLowerBound;
  final double? random;

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
    this.tags,
    this.isPublic = true,
    this.spotSource,
    this.spotSourceName,
    this.averageRating,
    this.ratingCount,
    this.wilsonLowerBound,
    this.random,
  });

  factory Spot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String? extractYoutubeId(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;
      // If it's already a likely ID, return as-is (11 chars typical)
      if (RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(trimmed) && !trimmed.contains('/')) {
        return trimmed;
      }
      try {
        final uri = Uri.parse(trimmed);
        // youtu.be/<id>
        if (uri.host.contains('youtu.be')) {
          final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
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
      youtubeVideoIds: extractYoutubeIdsList(
        data['youtubeVideoIds'],
      ),
      folderName: data['folderName'],
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      isPublic: data['isPublic'] ?? true,
      spotSource: data['spotSource'],
      spotSourceName: data['spotSourceName'],
      averageRating: data['averageRating'] != null ? (data['averageRating'] as num).toDouble() : null,
      ratingCount: data['ratingCount'],
      wilsonLowerBound: data['wilsonLowerBound'] != null ? (data['wilsonLowerBound'] as num).toDouble() : null,
      random: data['random'] != null ? (data['random'] as num).toDouble() : null,
    );
  }

  factory Spot.fromMap(Map<String, dynamic> data) {
    String? extractYoutubeId(String input) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) return null;
      if (RegExp(r'^[a-zA-Z0-9_-]{6,}$').hasMatch(trimmed) && !trimmed.contains('/')) {
        return trimmed;
      }
      try {
        final uri = Uri.parse(trimmed);
        if (uri.host.contains('youtu.be')) {
          final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
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
      youtubeVideoIds: extractYoutubeIdsList(
        data['youtubeVideoIds'],
      ),
      folderName: data['folderName'] as String?,
      createdBy: data['createdBy'] as String?,
      createdByName: data['createdByName'] as String?,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      tags: data['tags'] is List ? List<String>.from(data['tags']) : null,
      isPublic: data['isPublic'] as bool? ?? true,
      spotSource: data['spotSource'] as String?,
      spotSourceName: data['spotSourceName'] as String?,
      averageRating: (data['averageRating'] as num?)?.toDouble(),
      ratingCount: (data['ratingCount'] is int) ? data['ratingCount'] as int : (data['ratingCount'] as num?)?.toInt(),
      wilsonLowerBound: (data['wilsonLowerBound'] as num?)?.toDouble(),
      random: (data['random'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'countryCode': countryCode,
      'imageUrls': imageUrls,
      if (youtubeVideoIds != null) 'youtubeVideoIds': youtubeVideoIds,
      'folderName': folderName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'tags': tags,
      'isPublic': isPublic,
      'spotSource': spotSource,
      'spotSourceName': spotSourceName,
      if (averageRating != null) 'averageRating': averageRating,
      if (ratingCount != null) 'ratingCount': ratingCount,
      if (wilsonLowerBound != null) 'wilsonLowerBound': wilsonLowerBound,
      if (random != null) 'random': random,
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
    List<String>? youtubeVideoIds,
    String? folderName,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPublic,
    String? spotSource,
    String? spotSourceName,
    double? averageRating,
    int? ratingCount,
    double? wilsonLowerBound,
    double? random,
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
      youtubeVideoIds: youtubeVideoIds ?? this.youtubeVideoIds,
      folderName: folderName ?? this.folderName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      spotSource: spotSource ?? this.spotSource,
      spotSourceName: spotSourceName ?? this.spotSourceName,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      wilsonLowerBound: wilsonLowerBound ?? this.wilsonLowerBound,
      random: random ?? this.random,
    );
  }


  @override
  String toString() {
    return 'Spot(id: $id, name: $name, description: $description, lat: $latitude, lng: $longitude)';
  }
}
