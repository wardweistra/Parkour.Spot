import 'package:cloud_firestore/cloud_firestore.dart';

class Spot {
  final String? id;
  final String name;
  final String description;
  final GeoPoint location;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? countryCode;
  final List<String>? imageUrls;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? tags;
  final bool? isPublic;
  final String? spotSource;
  final String? geohash;

  Spot({
    this.id,
    required this.name,
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.countryCode,
    this.imageUrls,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.tags,
    this.isPublic = true,
    this.spotSource,
    this.geohash,
  });

  factory Spot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Spot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address'],
      city: data['city'],
      countryCode: data['countryCode'],
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl']] : null),
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      isPublic: data['isPublic'] ?? true,
      spotSource: data['spotSource'],
      geohash: data['geohash'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'countryCode': countryCode,
      'imageUrls': imageUrls,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'tags': tags,
      'isPublic': isPublic,
      'spotSource': spotSource,
      'geohash': geohash,
    };
  }

  Spot copyWith({
    String? id,
    String? name,
    String? description,
    GeoPoint? location,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    List<String>? imageUrls,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPublic,
    String? spotSource,
    String? geohash,
  }) {
    return Spot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      imageUrls: imageUrls ?? this.imageUrls,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      spotSource: spotSource ?? this.spotSource,
      geohash: geohash ?? this.geohash,
    );
  }

  // Convenience getters to get latitude and longitude from location if not explicitly set
  double get effectiveLatitude => latitude ?? location.latitude;
  double get effectiveLongitude => longitude ?? location.longitude;

  // Method to ensure latitude and longitude are populated from location
  Spot withLatLngFromLocation() {
    return copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  @override
  String toString() {
    return 'Spot(id: $id, name: $name, description: $description, location: $location)';
  }
}
