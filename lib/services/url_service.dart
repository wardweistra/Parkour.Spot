import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class UrlService {
  static const String _baseUrl = 'https://parkour.spot';
  
  /// Generate a shareable URL for a spot
  /// Uses format: parkour.spot/nl/amsterdam/&lt;spot-id&gt;
  static String generateSpotUrl(String spotId) {
    // For now, using a default country/city combination
    // In the future, this could be dynamic based on spot location
    return '$_baseUrl/nl/amsterdam/$spotId';
  }
  
  /// Share a spot URL using clipboard (web-compatible)
  static Future<void> shareSpot(String spotId, String spotName) async {
    final url = generateSpotUrl(spotId);
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
  static Future<void> copySpotUrl(String spotId) async {
    final url = generateSpotUrl(spotId);
    await Clipboard.setData(ClipboardData(text: url));
  }
  
  /// Open spot URL in browser
  static Future<void> openSpotInBrowser(String spotId) async {
    final url = generateSpotUrl(spotId);
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $url');
    }
  }
  
  /// Open spot URL in app (for deep linking)
  static Future<void> openSpotInApp(String spotId) async {
    final url = generateSpotUrl(spotId);
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
  
  /// Open location in external maps app
  /// On mobile: tries to open in native maps app (Google Maps, Apple Maps, etc.)
  /// On web: opens in Google Maps web
  static Future<void> openLocationInMaps(double latitude, double longitude, {String? label}) async {
    try {
      Uri uri;
      
      if (kIsWeb) {
        // On web, use Google Maps with exact coordinates and marker
        uri = Uri.parse('https://www.google.com/maps/place/$latitude,$longitude/@$latitude,$longitude,16z');
      } else {
        // On mobile, try to open in native maps app
        // First try Google Maps with exact coordinates and marker
        final googleMapsUrl = 'https://www.google.com/maps/place/$latitude,$longitude/@$latitude,$longitude,16z';
        uri = Uri.parse(googleMapsUrl);
        
        // If Google Maps can't be launched, try Apple Maps (iOS) with exact coordinates
        if (!await canLaunchUrl(uri)) {
          // Try Apple Maps format for iOS with exact coordinates
          final appleMapsUrl = 'https://maps.apple.com/?ll=$latitude,$longitude&z=16';
          uri = Uri.parse(appleMapsUrl);
          
          // If neither works, fall back to Google Maps web
          if (!await canLaunchUrl(uri)) {
            uri = Uri.parse(googleMapsUrl);
          }
        }
      }
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch maps app');
      }
    } catch (e) {
      debugPrint('Error opening location in maps: $e');
      rethrow;
    }
  }
}
