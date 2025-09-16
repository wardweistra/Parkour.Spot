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
}
