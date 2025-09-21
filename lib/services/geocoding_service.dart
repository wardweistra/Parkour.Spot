import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GeocodingService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Geocodes coordinates to a human-readable address
  /// Returns null if geocoding fails
  Future<String?> geocodeCoordinates(double latitude, double longitude) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('geocodeCoordinates');
      final result = await callable.call({
        'latitude': latitude,
        'longitude': longitude,
      });

      if (result.data['success'] == true) {
        return result.data['address'] as String?;
      } else {
        _error = result.data['error'] ?? 'Failed to geocode coordinates';
        return null;
      }
    } catch (e) {
      _error = 'Failed to geocode coordinates: $e';
      debugPrint('Error geocoding coordinates: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Geocodes coordinates silently (without notifying listeners)
  /// Used for background geocoding operations
  Future<String?> geocodeCoordinatesSilently(double latitude, double longitude) async {
    try {
      final callable = _functions.httpsCallable('geocodeCoordinates');
      final result = await callable.call({
        'latitude': latitude,
        'longitude': longitude,
      });

      if (result.data['success'] == true) {
        return result.data['address'] as String?;
      } else {
        debugPrint('Geocoding failed: ${result.data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error geocoding coordinates silently: $e');
      return null;
    }
  }

  /// Geocodes coordinates and returns address details including city and country code
  /// Notifies listeners during the operation
  Future<Map<String, String?>> geocodeCoordinatesDetails(double latitude, double longitude) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('geocodeCoordinates');
      final result = await callable.call({
        'latitude': latitude,
        'longitude': longitude,
      });

      if (result.data['success'] == true) {
        return {
          'address': result.data['address'] as String?,
          'city': result.data['city'] as String?,
          'countryCode': result.data['countryCode'] as String?,
        };
      } else {
        _error = result.data['error'] ?? 'Failed to geocode coordinates';
        return {
          'address': null,
          'city': null,
          'countryCode': null,
        };
      }
    } catch (e) {
      _error = 'Failed to geocode coordinates: $e';
      debugPrint('Error geocoding coordinates details: $e');
      return {
        'address': null,
        'city': null,
        'countryCode': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Geocodes coordinates silently and returns address details including city and country code
  Future<Map<String, String?>> geocodeCoordinatesDetailsSilently(double latitude, double longitude) async {
    try {
      final callable = _functions.httpsCallable('geocodeCoordinates');
      final result = await callable.call({
        'latitude': latitude,
        'longitude': longitude,
      });

      if (result.data['success'] == true) {
        return {
          'address': result.data['address'] as String?,
          'city': result.data['city'] as String?,
          'countryCode': result.data['countryCode'] as String?,
        };
      } else {
        debugPrint('Geocoding failed: ${result.data['error']}');
        return {
          'address': null,
          'city': null,
          'countryCode': null,
        };
      }
    } catch (e) {
      debugPrint('Error geocoding coordinates silently (details): $e');
      return {
        'address': null,
        'city': null,
        'countryCode': null,
      };
    }
  }

  /// Reverse geocodes an address to coordinates
  /// Returns null if reverse geocoding fails
  Future<Map<String, double>?> reverseGeocodeAddress(String address) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('reverseGeocodeAddress');
      final result = await callable.call({
        'address': address,
      });

      if (result.data['success'] == true) {
        return {
          'latitude': result.data['latitude'] as double,
          'longitude': result.data['longitude'] as double,
        };
      } else {
        _error = result.data['error'] ?? 'Failed to reverse geocode address';
        return null;
      }
    } catch (e) {
      _error = 'Failed to reverse geocode address: $e';
      debugPrint('Error reverse geocoding address: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Test function to check spots count in database
  Future<Map<String, dynamic>?> testSpotsCount() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('testSpotsCount');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      _error = 'Failed to test spots count: $e';
      debugPrint('Error testing spots count: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Trigger geocoding for all spots missing address fields
  Future<Map<String, dynamic>?> geocodeMissingSpotAddresses() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('geocodeMissingSpotAddresses');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      _error = 'Failed to trigger geocoding: $e';
      debugPrint('Error triggering geocoding of missing addresses: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Google Places Autocomplete (server-key via backend function)
  /// Returns list of suggestions with description and placeId
  Future<List<Map<String, dynamic>>> placesAutocomplete({
    required String input,
    String? sessionToken,
    double? biasLat,
    double? biasLng,
    int? radiusMeters,
    String? language,
  }) async {
    try {
      if (input.trim().isEmpty) return [];
      
      final callable = _functions.httpsCallable('placesAutocomplete');
      final result = await callable.call({
        'input': input,
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (biasLat != null && biasLng != null)
          'location': {
            'lat': biasLat,
            'lng': biasLng,
          },
        if (radiusMeters != null) 'radiusMeters': radiusMeters,
        if (language != null) 'language': language,
        'types': 'geocode',
      });
      
      if (result.data['success'] == true && result.data['suggestions'] is List) {
        return List<Map<String, dynamic>>.from(result.data['suggestions']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching places autocomplete: $e');
      return [];
    }
  }

  /// Place Details to get coordinates and formatted address (server-key via backend)
  /// Returns map with latitude, longitude, formattedAddress, city, countryCode
  Future<Map<String, dynamic>?> placeDetails({
    required String placeId,
    String? sessionToken,
    String? language,
  }) async {
    try {
      final callable = _functions.httpsCallable('placeDetails');
      final result = await callable.call({
        'placeId': placeId,
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (language != null) 'language': language,
      });
      if (result.data['success'] == true) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching place details: $e');
      return null;
    }
  }
}
