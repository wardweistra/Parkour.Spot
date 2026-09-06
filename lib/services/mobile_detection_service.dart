import 'package:flutter/foundation.dart';

import 'mobile_detection_service_web_impl.dart'
    if (dart.library.js_interop) 'mobile_detection_service_web.dart' as web_impl;

class MobileDetectionService {
  /// Mobile / tablet browser user agent (web only).
  ///
  /// Use for APIs like Web Share where touch PCs or short windows should still
  /// behave like desktop (clipboard + in-app feedback).
  static bool get isMobileUserAgent {
    if (!kIsWeb) return false;
    return web_impl.isMobileUserAgent();
  }

  /// Detects if the current device is mobile.
  /// On native, true for iOS/Android.
  static bool get isMobileDevice {
    if (!kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android;
    }
    return web_impl.isMobileDevice();
  }

  /// Detects if the device is iOS (iPhone/iPad).
  static bool get isIOS {
    if (!kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.iOS;
    }
    return web_impl.isIOS();
  }

  /// Detects if the device is Android.
  static bool get isAndroid {
    if (!kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    return web_impl.isAndroid();
  }

  /// Detects if the app is running as an installed PWA (standalone mode).
  /// Always false on native (native is not a PWA).
  static bool get isRunningAsPWA {
    if (!kIsWeb) return false;
    return web_impl.isRunningAsPWA();
  }

  /// Detects if the app is running in a regular browser (not PWA).
  static bool get isRunningInBrowser {
    if (!kIsWeb) return false;
    return !isRunningAsPWA;
  }

  /// Gets the preferred maps app for the current device.
  static String get preferredMapsApp {
    if (isIOS) return 'apple_maps';
    if (isAndroid) return 'google_maps';
    return 'google_maps';
  }

  /// Get detailed device information for debugging.
  static Map<String, dynamic> get detailedDeviceInfo {
    if (!kIsWeb) {
      return {
        'platform': 'native_mobile',
        'defaultTargetPlatform': '$defaultTargetPlatform',
        'isMobileDevice': isMobileDevice,
        'isIOS': isIOS,
        'isAndroid': isAndroid,
        'preferredMapsApp': preferredMapsApp,
      };
    }
    return web_impl.detailedDeviceInfo();
  }
}
