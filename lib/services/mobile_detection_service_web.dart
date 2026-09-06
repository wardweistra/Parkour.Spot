import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

bool isMobileUserAgent() {
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

bool isMobileDevice() {
  try {
    if (isMobileUserAgent()) return true;

    final screenWidth = web.window.screen.width;
    final screenHeight = web.window.screen.height;
    final isSmallScreen = screenWidth < 768 || screenHeight < 768;
    final hasTouchSupport = web.window.navigator.maxTouchPoints > 0;
    return isSmallScreen && hasTouchSupport;
  } catch (e) {
    debugPrint('Error detecting mobile device: $e');
    return false;
  }
}

bool isIOS() {
  try {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') || userAgent.contains('ipad');
  } catch (e) {
    debugPrint('Error detecting iOS: $e');
    return false;
  }
}

bool isAndroid() {
  try {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('android');
  } catch (e) {
    debugPrint('Error detecting Android: $e');
    return false;
  }
}

bool isRunningAsPWA() {
  try {
    final standaloneMatch = web.window.matchMedia('(display-mode: standalone)');
    final fullscreenMatch = web.window.matchMedia('(display-mode: fullscreen)');
    final minimalUiMatch = web.window.matchMedia('(display-mode: minimal-ui)');

    if (standaloneMatch.matches ||
        fullscreenMatch.matches ||
        minimalUiMatch.matches) {
      return true;
    }

    try {
      final standalone = (web.window.navigator as dynamic).standalone;
      if (standalone == true) {
        return true;
      }
    } catch (_) {}

    return false;
  } catch (e) {
    debugPrint('Error detecting PWA mode: $e');
    return false;
  }
}

Map<String, dynamic> detailedDeviceInfo() {
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
      'isMobileDevice': isMobileDevice(),
      'isIOS': isIOS(),
      'isAndroid': isAndroid(),
      'isRunningAsPWA': isRunningAsPWA(),
      'isRunningInBrowser': !isRunningAsPWA(),
      'preferredMapsApp': isIOS()
          ? 'apple_maps'
          : (isAndroid() ? 'google_maps' : 'google_maps'),
    };
  } catch (e) {
    return {
      'platform': 'web',
      'error': e.toString(),
      'isMobileDevice': false,
    };
  }
}
