import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for geohash operations
class GeohashUtils {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Calculate geohash from latitude and longitude coordinates
  /// 
  /// [latitude] - The latitude coordinate
  /// [longitude] - The longitude coordinate
  /// [precision] - The precision of the geohash (default: 12 characters)
  /// 
  /// Returns a geohash string
  static String calculateGeohash(double latitude, double longitude, {int precision = 12}) {
    double latMin = -90.0;
    double latMax = 90.0;
    double lonMin = -180.0;
    double lonMax = 180.0;

    String geohash = '';
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (geohash.length < precision) {
      if (isEven) {
        // Longitude
        double lonMid = (lonMin + lonMax) / 2;
        if (longitude >= lonMid) {
          ch |= (1 << (4 - bit));
          lonMin = lonMid;
        } else {
          lonMax = lonMid;
        }
      } else {
        // Latitude
        double latMid = (latMin + latMax) / 2;
        if (latitude >= latMid) {
          ch |= (1 << (4 - bit));
          latMin = latMid;
        } else {
          latMax = latMid;
        }
      }

      isEven = !isEven;

      if (bit < 4) {
        bit++;
      } else {
        geohash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }

    return geohash;
  }

  /// Calculate geohash from a GeoPoint
  /// 
  /// [geoPoint] - The GeoPoint containing latitude and longitude
  /// [precision] - The precision of the geohash (default: 12 characters)
  /// 
  /// Returns a geohash string
  static String calculateGeohashFromGeoPoint(GeoPoint geoPoint, {int precision = 12}) {
    return calculateGeohash(geoPoint.latitude, geoPoint.longitude, precision: precision);
  }

  /// Get geohash neighbors for proximity searches
  /// 
  /// [geohash] - The base geohash
  /// 
  /// Returns a list of neighboring geohashes
  static List<String> getNeighbors(String geohash) {
    List<String> neighbors = [];
    
    // North
    neighbors.add(_adjacent(geohash, 'n'));
    // Northeast
    neighbors.add(_adjacent(_adjacent(geohash, 'n'), 'e'));
    // East
    neighbors.add(_adjacent(geohash, 'e'));
    // Southeast
    neighbors.add(_adjacent(_adjacent(geohash, 's'), 'e'));
    // South
    neighbors.add(_adjacent(geohash, 's'));
    // Southwest
    neighbors.add(_adjacent(_adjacent(geohash, 's'), 'w'));
    // West
    neighbors.add(_adjacent(geohash, 'w'));
    // Northwest
    neighbors.add(_adjacent(_adjacent(geohash, 'n'), 'w'));
    
    return neighbors;
  }

  /// Get geohash neighbors including the original geohash
  /// 
  /// [geohash] - The base geohash
  /// 
  /// Returns a list of neighboring geohashes including the original
  static List<String> getNeighborsWithSelf(String geohash) {
    final neighbors = getNeighbors(geohash);
    return [geohash, ...neighbors];
  }

  /// Calculate adjacent geohash in given direction
  static String _adjacent(String geohash, String direction) {
    if (geohash.isEmpty) return '';
    
    String base = geohash.substring(0, geohash.length - 1);
    String lastChar = geohash[geohash.length - 1];
    
    int lastCharIndex = _base32.indexOf(lastChar);
    int neighborIndex = _getNeighborIndex(lastCharIndex, direction);
    
    if (neighborIndex == -1) {
      return _adjacent(base, direction) + _base32[0];
    }
    
    return base + _base32[neighborIndex];
  }

  /// Get neighbor index for a given character and direction
  static int _getNeighborIndex(int charIndex, String direction) {
    switch (direction) {
      case 'n':
        return _northNeighbor[charIndex];
      case 's':
        return _southNeighbor[charIndex];
      case 'e':
        return _eastNeighbor[charIndex];
      case 'w':
        return _westNeighbor[charIndex];
      default:
        return -1;
    }
  }

  // Neighbor lookup tables
  static const List<int> _northNeighbor = [
    1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
    17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30
  ];

  static const List<int> _southNeighbor = [
    1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
    17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30
  ];

  static const List<int> _eastNeighbor = [
    1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
    17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30
  ];

  static const List<int> _westNeighbor = [
    1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
    17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30
  ];
}
