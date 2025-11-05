import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'mobile_detection_service.dart';

class UrlService {
  static const String _baseUrl = 'https://parkour.spot';
  
  /// Generate a shareable URL for a spot
  /// Uses format: parkour.spot/nl/amsterdam/&lt;spot-id&gt;
  static String generateSpotUrl(String spotId, {String? countryCode, String? city}) {
    if (countryCode != null && countryCode.length == 2) {
      final cc = countryCode.toLowerCase();
      final citySegment = (city != null && city.trim().isNotEmpty)
          ? _slugify(city)
          : 'city';
      return '$_baseUrl/$cc/$citySegment/$spotId';
    }
    return '$_baseUrl/spot/$spotId';
  }
  
  /// Share a spot URL using clipboard (web-compatible)
  static Future<void> shareSpot(String spotId, String spotName, {String? countryCode, String? city}) async {
    final url = generateSpotUrl(spotId, countryCode: countryCode, city: city);
    final text = 'Check out this parkour spot: $spotName\n\n$url';
    
    try {
      // Copy to clipboard (works on both web and mobile)
      await Clipboard.setData(ClipboardData(text: text));
      
      // Show success feedback
      if (kIsWeb) {
        debugPrint('URL copied to clipboard: $url');
        // In a real web app, you might want to show a toast notification
      } else {
        // On mobile, you could show a snackbar or other feedback
        debugPrint('URL copied to clipboard: $url');
      }
    } catch (e) {
      debugPrint('Error sharing spot: $e');
    }
  }
  
  /// Copy spot URL to clipboard
  static Future<void> copySpotUrl(String spotId, {String? countryCode, String? city}) async {
    final url = generateSpotUrl(spotId, countryCode: countryCode, city: city);
    await Clipboard.setData(ClipboardData(text: url));
  }
  
  /// Open spot URL in browser
  static Future<void> openSpotInBrowser(String spotId, {String? countryCode, String? city}) async {
    final url = generateSpotUrl(spotId, countryCode: countryCode, city: city);
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $url');
    }
  }
  
  /// Open spot URL in app (for deep linking)
  static Future<void> openSpotInApp(String spotId, {String? countryCode, String? city}) async {
    final url = generateSpotUrl(spotId, countryCode: countryCode, city: city);
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      throw Exception('Could not launch $url');
    }
  }
  
  /// Extract spot ID from URL
  /// Supports format: parkour.spot/&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
  /// where xx is a 2-letter country code
  static String? extractSpotIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Format: /nl/amsterdam/&lt;spot-id&gt; or any /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
      if (pathSegments.length == 3) {
        // Check if first segment is 2 letters (country code) and third is the spot ID
        if (pathSegments[0].length == 2 && 
            RegExp(r'^[a-zA-Z]{2}$').hasMatch(pathSegments[0])) {
          return pathSegments[2];
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if URL is a valid spot URL
  static bool isValidSpotUrl(String url) {
    return extractSpotIdFromUrl(url) != null;
  }

  static String _slugify(String input) {
    // First, normalize special characters to ASCII equivalents
    final normalized = _normalizeToAscii(input);
    final lowered = normalized.toLowerCase();
    final replaced = lowered
        .replaceAll(RegExp(r"[^a-z0-9\s-_]", caseSensitive: false), '')
        .replaceAll(RegExp(r"[\s_]+"), '-');
    return replaced;
  }

  /// Normalize special characters to their ASCII equivalents
  /// e.g., é -> e, É -> e, ñ -> n, etc.
  static String _normalizeToAscii(String input) {
    // Common accented characters and their ASCII equivalents
    const Map<String, String> replacements = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'ý': 'y', 'ÿ': 'y',
      'Ý': 'Y', 'Ÿ': 'Y',
      'ñ': 'n', 'Ñ': 'N',
      'ç': 'c', 'Ç': 'C',
      'ß': 'ss',
    };
    
    String result = input;
    replacements.forEach((char, replacement) {
      result = result.replaceAll(char, replacement);
    });
    
    return result;
  }
  
  /// Open location in external maps app
  /// On mobile: tries to open in native maps app (Google Maps, Apple Maps, etc.)
  /// On web: opens in Google Maps web
  /// On web + mobile device: tries to open in native maps app first
  static Future<void> openLocationInMaps(double latitude, double longitude, {double? zoom, bool isSatellite = false}) async {
    try {
      Uri uri;
      
      if (kIsWeb) {
        // Check if we're on a mobile device in the web version
        if (MobileDetectionService.isMobileDevice) {
          // Try to open in native maps app first
          uri = _getNativeMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
        } else {
          // Desktop web - use Google Maps web
          uri = _buildGoogleMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
        }
      } else {
        // Native mobile app - use native maps
        uri = _getNativeMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
      }
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web if native app can't be launched
        final fallbackUri = _buildGoogleMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch any maps app');
        }
      }
    } catch (e) {
      debugPrint('Error opening location in maps: $e');
      rethrow;
    }
  }
  
  /// Build Google Maps URL in the format: https://maps.google.com/?q=lat,lon&z=zoom&t=type
  static Uri _buildGoogleMapsUri(double latitude, double longitude, {double? zoom, bool isSatellite = false}) {
    final queryParams = <String, String>{
      'q': '$latitude,$longitude',
    };
    
    if (zoom != null) {
      queryParams['z'] = zoom.toStringAsFixed(0);
    }
    
    queryParams['t'] = isSatellite ? 'k' : 'm';
    
    return Uri.https('maps.google.com', '/', queryParams);
  }
  
  /// Build Apple Maps URL in the format: http://maps.apple.com/?q=lat,lon&z=zoom&t=type
  static Uri _buildAppleMapsUri(double latitude, double longitude, {double? zoom, bool isSatellite = false}) {
    final queryParams = <String, String>{
      'q': '$latitude,$longitude',
    };
    
    if (zoom != null) {
      queryParams['z'] = zoom.toStringAsFixed(0);
    }
    
    queryParams['t'] = isSatellite ? 'k' : 'm';
    
    return Uri.http('maps.apple.com', '/', queryParams);
  }
  
  /// Get the appropriate native maps URI based on device type
  static Uri _getNativeMapsUri(double latitude, double longitude, {double? zoom, bool isSatellite = false}) {
    final preferredApp = MobileDetectionService.preferredMapsApp;
    
    if (preferredApp == 'apple_maps') {
      return _buildAppleMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
    } else {
      return _buildGoogleMapsUri(latitude, longitude, zoom: zoom, isSatellite: isSatellite);
    }
  }
  
  /// Generate a navigation URL for a spot (for internal navigation)
  /// Uses the same format as share URLs: /countryCode/city/spotId
  static String generateNavigationUrl(String spotId, {String? countryCode, String? city}) {
    if (countryCode != null && countryCode.length == 2) {
      final cc = countryCode.toLowerCase();
      final citySegment = (city != null && city.trim().isNotEmpty)
          ? _slugify(city)
          : 'city';
      return '/$cc/$citySegment/$spotId';
    }
    return '/spot/$spotId';
  }

  /// Check if the current device can open native maps apps
  static bool get canOpenNativeMaps {
    if (!kIsWeb) return true; // Native mobile apps can always open maps
    return MobileDetectionService.isMobileDevice;
  }
  
  /// Get device information for debugging and user experience
  static Map<String, dynamic> get deviceInfo {
    return {
      'platform': 'web',
      'isMobileDevice': MobileDetectionService.isMobileDevice,
      'isIOS': MobileDetectionService.isIOS,
      'isAndroid': MobileDetectionService.isAndroid,
      'canOpenNativeMaps': MobileDetectionService.isMobileDevice,
      'preferredMapsApp': MobileDetectionService.preferredMapsApp,
    };
  }
}
