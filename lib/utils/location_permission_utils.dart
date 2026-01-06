import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Utility class for handling location permissions consistently across the app.
class LocationPermissionUtils {
  /// Checks and requests location permission if needed.
  /// 
  /// Returns the permission status after checking and potentially requesting.
  /// Shows user-friendly error messages via SnackBar if permission is denied.
  /// 
  /// [context] - BuildContext for showing SnackBar messages (optional, can be null for silent checks)
  /// [showErrorMessages] - Whether to show error messages to the user (default: true)
  /// 
  /// Returns the LocationPermission status.
  static Future<LocationPermission> checkAndRequestPermission({
    BuildContext? context,
    bool showErrorMessages = true,
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        if (showErrorMessages && context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return permission;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (showErrorMessages && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in your device settings.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return permission;
    }

    return permission;
  }

  /// Checks if the permission is granted (either whileInUse or always).
  static bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Gets the current position with proper permission handling.
  /// 
  /// Returns the Position if successful, null otherwise.
  /// Shows user-friendly error messages via SnackBar if permission is denied.
  /// 
  /// [context] - BuildContext for showing SnackBar messages (optional)
  /// [showErrorMessages] - Whether to show error messages to the user (default: true)
  /// [accuracy] - Location accuracy setting (default: LocationAccuracy.high)
  /// 
  /// Returns the Position if successful, null if permission denied or error occurs.
  static Future<Position?> getCurrentPositionWithPermission({
    BuildContext? context,
    bool showErrorMessages = true,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final permission = await checkAndRequestPermission(
      context: context,
      showErrorMessages: showErrorMessages,
    );

    if (!isPermissionGranted(permission)) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
        ),
      );
      return position;
    } catch (e) {
      if (showErrorMessages && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}

