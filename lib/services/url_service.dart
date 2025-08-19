import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class UrlService {
  static const String _baseUrl = 'https://parkour.spot';
  
  /// Generate a shareable URL for a spot
  static String generateSpotUrl(String spotId) {
    return '$_baseUrl/spot/$spotId';
  }
  
  /// Generate a shorter shareable URL for a spot
  static String generateShortSpotUrl(String spotId) {
    return '$_baseUrl/s/$spotId';
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
  static String? extractSpotIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length == 2 && 
          (pathSegments[0] == 'spot' || pathSegments[0] == 's')) {
        return pathSegments[1];
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
}
