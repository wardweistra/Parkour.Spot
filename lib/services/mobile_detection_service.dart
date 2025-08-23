import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class MobileDetectionService {
  /// Detects if the current device is mobile based on user agent and screen size
  /// This works specifically for web platforms
  static bool get isMobileDevice {
    if (!kIsWeb) return false;
    
    try {
      // Check user agent for mobile devices
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      final isMobileUserAgent = userAgent.contains('mobile') || 
                               userAgent.contains('android') || 
                               userAgent.contains('iphone') || 
                               userAgent.contains('ipad') ||
                               userAgent.contains('windows phone');
      
      // Check screen size (mobile devices typically have smaller screens)
      final screenWidth = web.window.screen.width;
      final screenHeight = web.window.screen.height;
      final isSmallScreen = screenWidth < 768 || screenHeight < 768;
      
      // Check if device supports touch (most mobile devices do)
      final hasTouchSupport = web.window.navigator.maxTouchPoints > 0;
      
      // Consider it mobile if it has mobile user agent OR small screen with touch support
      return isMobileUserAgent || (isSmallScreen && hasTouchSupport);
    } catch (e) {
      // Fallback: if we can't detect, assume it's not mobile
      debugPrint('Error detecting mobile device: $e');
      return false;
    }
  }
  
  /// Detects if the device is iOS (iPhone/iPad)
  static bool get isIOS {
    if (!kIsWeb) return false;
    
    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('iphone') || userAgent.contains('ipad');
    } catch (e) {
      debugPrint('Error detecting iOS device: $e');
      return false;
    }
  }
  
  /// Detects if the device is Android
  static bool get isAndroid {
    if (!kIsWeb) return false;
    
    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('android');
    } catch (e) {
      debugPrint('Error detecting Android device: $e');
      return false;
    }
  }
  
  /// Gets the preferred maps app for the current device
  static String get preferredMapsApp {
    if (isIOS) return 'apple_maps';
    if (isAndroid) return 'google_maps';
    return 'google_maps'; // Default fallback
  }
  
  /// Get detailed device information for debugging
  static Map<String, dynamic> get detailedDeviceInfo {
    if (!kIsWeb) return {'platform': 'native_mobile'};
    
    try {
      final userAgent = web.window.navigator.userAgent;
      final screenWidth = web.window.screen.width;
      final screenHeight = web.window.screen.height;
      final maxTouchPoints = web.window.navigator.maxTouchPoints;
      
      return {
        'platform': 'web',
        'userAgent': userAgent,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'maxTouchPoints': maxTouchPoints,
        'isMobileDevice': isMobileDevice,
        'isIOS': isIOS,
        'isAndroid': isAndroid,
        'preferredMapsApp': preferredMapsApp,
      };
    } catch (e) {
      return {
        'platform': 'web',
        'error': e.toString(),
        'isMobileDevice': false,
      };
    }
  }
}
