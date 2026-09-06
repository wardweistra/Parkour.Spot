import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:parkour_spot/services/mobile_detection_service.dart';

/// Service for handling PWA installation prompts
/// 
/// This service listens for the `beforeinstallprompt` event (Chrome/Edge/Android)
/// and provides methods to check if installation is available and trigger the prompt.
/// 
/// The service remembers if the user has dismissed the prompt and only shows it
/// after the user has been using the app for a bit (to avoid being annoying).
class PwaInstallService extends ChangeNotifier {
  static PwaInstallService? _instance;
  
  PwaInstallService._();
  
  factory PwaInstallService() {
    _instance ??= PwaInstallService._();
    return _instance!;
  }
  
  // Storage keys
  static const String _keyDismissed = 'pwa_install_dismissed';
  static const String _keyDismissedTimestamp = 'pwa_install_dismissed_timestamp';
  static const String _keyShowCount = 'pwa_install_show_count';
  static const String _keyFirstSeenTimestamp = 'pwa_install_first_seen_timestamp';
  static const String _keyPageViewCount = 'pwa_install_page_view_count';
  
  // Configuration
  static const int _maxShowCount = 3; // Maximum times to show the prompt
  static const int _minPageViews = 3; // Show after user has viewed at least 3 pages
  static const int _minTimeBeforeShow = 30; // Show after at least 30 seconds of usage
  static const int _dismissCooldownDays = 7; // Show again after 7 days if dismissed
  
  /// The deferred install prompt event (Chrome/Edge/Android)
  /// Stored as dynamic to allow calling prompt() method
  dynamic _deferredPrompt;
  
  /// Whether the install prompt is available
  bool _isInstallPromptAvailable = false;
  
  /// Whether the app is already installed
  bool _isInstalled = false;
  
  /// Whether the prompt has been dismissed
  bool _isDismissed = false;
  
  /// Timestamp when prompt was dismissed
  int? _dismissedTimestamp;
  
  /// Number of times the prompt has been shown
  int _showCount = 0;
  
  /// Timestamp when user first visited (for timing logic)
  int? _firstSeenTimestamp;
  
  /// Page view count (for engagement logic)
  int _pageViewCount = 0;
  
  /// Stream controller for install prompt availability changes
  final _availabilityController = StreamController<bool>.broadcast();
  
  /// Stream that emits when install prompt availability changes
  Stream<bool> get installPromptAvailability => _availabilityController.stream;
  
  /// Whether the install prompt is currently available
  bool get isInstallPromptAvailable => _isInstallPromptAvailable;
  
  /// Whether the app is already installed as a PWA
  bool get isInstalled => _isInstalled;
  
  /// Whether the prompt should be shown (considering all conditions)
  /// Note: We no longer require isInstallPromptAvailable since we show instructions for all platforms
  bool get shouldShowPrompt {
    if (!kIsWeb) return false;
    if (_isInstalled) return false;
    if (!MobileDetectionService.isMobileDevice) return false;
    
    // Check if dismissed and within cooldown period
    if (_isDismissed && _dismissedTimestamp != null) {
      final daysSinceDismissal = 
          (DateTime.now().millisecondsSinceEpoch - _dismissedTimestamp!) / 
          (1000 * 60 * 60 * 24);
      if (daysSinceDismissal < _dismissCooldownDays) {
        return false; // Still in cooldown period
      }
    }
    
    // Check if we've shown it too many times
    if (_showCount >= _maxShowCount) {
      return false;
    }
    
    // Check engagement requirements
    if (_pageViewCount < _minPageViews) {
      return false;
    }
    
    // Check time requirement
    if (_firstSeenTimestamp != null) {
      final secondsSinceFirstSeen = 
          (DateTime.now().millisecondsSinceEpoch - _firstSeenTimestamp!) / 1000;
      if (secondsSinceFirstSeen < _minTimeBeforeShow) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Whether installation is supported on this platform
  bool get isInstallSupported {
    if (!kIsWeb) return false;
    return MobileDetectionService.isMobileDevice;
  }
  
  /// Get debug information about the PWA install service state
  /// Useful for admin screens and testing
  Map<String, dynamic> get debugInfo {
    return {
      // Note: isInstallPromptAvailable is for diagnostics only - we always show instructions
      'chromeInstallButtonAvailable': _isInstallPromptAvailable, // Whether Chrome might show its own install button
      'isInstalled': _isInstalled,
      'isInstallSupported': isInstallSupported,
      'shouldShowPrompt': shouldShowPrompt, // Controls Explore banner visibility (engagement-based)
      'showCount': _showCount,
      'pageViewCount': _pageViewCount,
      'firstSeenTimestamp': _firstSeenTimestamp,
      'isDismissed': _isDismissed,
      'dismissedTimestamp': _dismissedTimestamp,
      'dismissCooldownDays': _dismissCooldownDays,
      'maxShowCount': _maxShowCount,
      'minPageViews': _minPageViews,
      'minTimeBeforeShow': _minTimeBeforeShow,
    };
  }
  
  /// Initialize the service and set up event listeners
  Future<void> initialize() async {
    if (!kIsWeb) return;
    
    // Load persisted state
    await _loadState();
    
    // Check if already installed
    _isInstalled = MobileDetectionService.isRunningAsPWA;
    
    // If installed, clear dismissal state
    if (_isInstalled) {
      await _clearDismissalState();
    }
    
    // Track first visit if not already tracked
    if (_firstSeenTimestamp == null) {
      _firstSeenTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _saveFirstSeenTimestamp();
    }
    
    // Listen for the beforeinstallprompt event (Chrome/Edge/Android)
    web.window.addEventListener('beforeinstallprompt', _handleBeforeInstallPrompt.toJS);
    
    // Listen for app installed event
    web.window.addEventListener('appinstalled', _handleAppInstalled.toJS);
    
    // For iOS, we can't detect install prompt availability, but we can show instructions
    if (MobileDetectionService.isIOS && !_isInstalled) {
      _isInstallPromptAvailable = true;
      _availabilityController.add(true);
    }
    
    notifyListeners();
  }
  
  /// Track a page view (call this from your router/navigation)
  Future<void> trackPageView() async {
    if (!kIsWeb || _isInstalled) return;
    
    _pageViewCount++;
    await _savePageViewCount();
    notifyListeners();
  }
  
  /// Handle the beforeinstallprompt event
  void _handleBeforeInstallPrompt(JSAny event) {
    if (!kIsWeb) return;
    
    try {
      // Prevent the default browser install prompt
      final jsEvent = event as web.Event;
      jsEvent.preventDefault();
      
      // Store the event for later use as dynamic to allow method calls
      _deferredPrompt = event as dynamic;
      _isInstallPromptAvailable = true;
      _isInstalled = false;
      
      notifyListeners();
      _availabilityController.add(true);
      
      debugPrint('PWA install prompt is now available');
    } catch (e) {
      debugPrint('Error handling beforeinstallprompt: $e');
    }
  }
  
  /// Handle the appinstalled event
  void _handleAppInstalled(JSAny event) {
    if (!kIsWeb) return;
    
    _deferredPrompt = null;
    _isInstallPromptAvailable = false;
    _isInstalled = true;
    
    // Clear dismissal state since app is now installed
    _clearDismissalState();
    
    notifyListeners();
    _availabilityController.add(false);
    
    debugPrint('PWA has been installed');
  }
  
  /// Prompt the user to install the PWA
  /// 
  /// Returns true if the prompt was shown, false otherwise.
  /// On iOS, this returns false and you should show manual instructions instead.
  Future<bool> promptInstall() async {
    if (!kIsWeb) return false;
    
    // If already installed, don't show prompt
    if (_isInstalled) {
      debugPrint('PWA is already installed');
      return false;
    }
    
    // On iOS, we can't programmatically trigger install
    if (MobileDetectionService.isIOS) {
      debugPrint('iOS requires manual installation - show instructions instead');
      return false;
    }
    
    // If no deferred prompt is available, can't install
    if (_deferredPrompt == null) {
      debugPrint('Install prompt is not available');
      return false;
    }
    
    try {
      // Call prompt() on the deferred event using dynamic invocation
      if (_deferredPrompt != null) {
        // Use dynamic to call the prompt() method
        // This works at runtime even though the type system doesn't know about it
        // The prompt() method returns a Promise, but we don't need to await it
        (_deferredPrompt as dynamic).prompt();
        
        // prompt() returns a Promise, but we don't need to await it
        // The user's choice will be handled by the appinstalled event
        
        // Increment show count
        _showCount++;
        await _saveShowCount();
        
        // Wait for user's choice (they may accept or dismiss)
        // The appinstalled event will fire if they accept
        return true;
      }
    } catch (e) {
      debugPrint('Error showing install prompt: $e');
    }
    
    return false;
  }
  
  /// Mark the prompt as dismissed
  Future<void> dismissPrompt() async {
    _isDismissed = true;
    _dismissedTimestamp = DateTime.now().millisecondsSinceEpoch;
    _showCount++;
    await _saveDismissalState();
    await _saveShowCount();
    notifyListeners();
  }
  
  /// Get installation instructions for iOS
  Map<String, String> getIOSInstallInstructions() {
    return {
      'title': 'Install Parkour·Spot',
      'step1': 'Tap the Share button at the bottom of the screen',
      'step2': 'Scroll down and tap "Add to Home Screen"',
      'step3': 'Tap "Add" in the top right corner',
      'step4': 'The app will appear on your home screen!',
    };
  }
  
  /// Get installation instructions for Android/Chrome
  Map<String, String> getAndroidInstallInstructions() {
    return {
      'title': 'Install Parkour·Spot',
      'step1': 'Tap the More menu (⋯) in the top right corner',
      'step2': 'Tap "Add to home screen"',
      'step3': 'Tap "Install app"',
      'step4': 'The app will appear on your home screen!',
    };
  }
  
  // Private methods for persistence
  
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDismissed = prefs.getBool(_keyDismissed) ?? false;
      _dismissedTimestamp = prefs.getInt(_keyDismissedTimestamp);
      _showCount = prefs.getInt(_keyShowCount) ?? 0;
      _firstSeenTimestamp = prefs.getInt(_keyFirstSeenTimestamp);
      _pageViewCount = prefs.getInt(_keyPageViewCount) ?? 0;
    } catch (e) {
      debugPrint('Error loading PWA install state: $e');
    }
  }
  
  Future<void> _saveDismissalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDismissed, true);
      await prefs.setInt(_keyDismissedTimestamp, _dismissedTimestamp!);
    } catch (e) {
      debugPrint('Error saving PWA install dismissal: $e');
    }
  }
  
  Future<void> _saveShowCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyShowCount, _showCount);
    } catch (e) {
      debugPrint('Error saving PWA install show count: $e');
    }
  }
  
  Future<void> _saveFirstSeenTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyFirstSeenTimestamp, _firstSeenTimestamp!);
    } catch (e) {
      debugPrint('Error saving PWA install first seen timestamp: $e');
    }
  }
  
  Future<void> _savePageViewCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPageViewCount, _pageViewCount);
    } catch (e) {
      debugPrint('Error saving PWA install page view count: $e');
    }
  }
  
  Future<void> _clearDismissalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDismissed);
      await prefs.remove(_keyDismissedTimestamp);
      _isDismissed = false;
      _dismissedTimestamp = null;
    } catch (e) {
      debugPrint('Error clearing PWA install dismissal: $e');
    }
  }
  
  /// Clean up resources
  @override
  void dispose() {
    if (kIsWeb) {
      web.window.removeEventListener('beforeinstallprompt', _handleBeforeInstallPrompt.toJS);
      web.window.removeEventListener('appinstalled', _handleAppInstalled.toJS);
    }
    _availabilityController.close();
    super.dispose();
  }
}
