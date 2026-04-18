import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class MobileDetectionService {
  /// Mobile / tablet browser user agent (web only).
  ///
  /// Use for APIs like Web Share where touch PCs or short windows should still
  /// behave like desktop (clipboard + in-app feedback).
  static bool get isMobileUserAgent {
    if (!kIsWeb) return false;
    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('mobile') ||
          userAgent.contains('android') ||
          userAgent.contains('iphone') ||
          userAgent.contains('ipad') ||
          userAgent.contains('windows phone');
    } catch (e) {
      debugPrint('Error detecting mobile user agent: $e');
      return false;
    }
  }

  /// Detects if the current device is mobile based on user agent and screen size
  /// This works specifically for web platforms
  static bool get isMobileDevice {
    if (!kIsWeb) return false;

    try {
      if (isMobileUserAgent) return true;

      // Check screen size (mobile devices typically have smaller screens)
      final screenWidth = web.window.screen.width;
      final screenHeight = web.window.screen.height;
      final isSmallScreen = screenWidth < 768 || screenHeight < 768;

      // Check if device supports touch (most mobile devices do)
      final hasTouchSupport = web.window.navigator.maxTouchPoints > 0;

      // Touch laptop or short window: still treat as mobile for layout / keyboard, etc.
      return isSmallScreen && hasTouchSupport;
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
  
  /// Detects if the app is running as an installed PWA (standalone mode)
  /// Returns true if the app is running in standalone, fullscreen, or minimal-ui display mode
  static bool get isRunningAsPWA {
    if (!kIsWeb) return false;
    
    try {
      // Standard way: Check display-mode media query
      // This works for most modern browsers
      final standaloneMatch = web.window.matchMedia('(display-mode: standalone)');
      final fullscreenMatch = web.window.matchMedia('(display-mode: fullscreen)');
      final minimalUiMatch = web.window.matchMedia('(display-mode: minimal-ui)');
      
      if (standaloneMatch.matches || fullscreenMatch.matches || minimalUiMatch.matches) {
        return true;
      }
      
      // iOS Safari specific: Check navigator.standalone
      // This is a boolean that's true when running from home screen
      // Note: This property may not exist on all browsers, so we check safely
      try {
        final standalone = (web.window.navigator as dynamic).standalone;
        if (standalone == true) {
          return true;
        }
      } catch (_) {
        // Property doesn't exist, which is fine
      }
      
      return false;
    } catch (e) {
      debugPrint('Error detecting PWA mode: $e');
      return false;
    }
  }
  
  /// Detects if the app is running in a regular browser (not PWA)
  static bool get isRunningInBrowser {
    if (!kIsWeb) return false;
    return !isRunningAsPWA;
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
        'isRunningAsPWA': isRunningAsPWA,
        'isRunningInBrowser': isRunningInBrowser,
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
