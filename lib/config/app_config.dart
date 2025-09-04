import 'dart:io';
import 'package:flutter/foundation.dart';

// Helper function to get environment variables for both web and mobile
String _getEnvVar(String key, String defaultValue) {
  // For web, use String.fromEnvironment (--dart-define values)
  if (kIsWeb) {
    return String.fromEnvironment(key, defaultValue: defaultValue);
  }
  
  // For mobile, use Platform.environment
  return Platform.environment[key] ?? defaultValue;
}

// Web-specific environment variable getters (const for compile-time evaluation)
class WebEnvVars {
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const String firebaseAppIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const String firebaseAppIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const String firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String firebaseMeasurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  static const String googleMapsApiKeyAndroid = String.fromEnvironment('GOOGLE_MAPS_API_KEY_ANDROID');
  static const String googleMapsApiKeyIos = String.fromEnvironment('GOOGLE_MAPS_API_KEY_IOS');
}

class AppConfig {
  static const String _defaultApiKey = '';
  static const String _defaultAppId = '';
  static const String _defaultProjectId = '';
  
  // Firebase Configuration
  static String get firebaseApiKey => 
      kIsWeb ? WebEnvVars.firebaseApiKey : _getEnvVar('FIREBASE_API_KEY', _defaultApiKey);
  
  // Platform-specific App IDs
  static String get firebaseAppIdWeb => 
      kIsWeb ? WebEnvVars.firebaseAppIdWeb : _getEnvVar('FIREBASE_APP_ID_WEB', _defaultAppId);
  
  static String get firebaseAppIdAndroid => 
      kIsWeb ? WebEnvVars.firebaseAppIdAndroid : _getEnvVar('FIREBASE_APP_ID_ANDROID', _defaultAppId);
  
  static String get firebaseAppIdIos => 
      kIsWeb ? WebEnvVars.firebaseAppIdIos : _getEnvVar('FIREBASE_APP_ID_IOS', _defaultAppId);
  
  // Helper method to get the appropriate App ID for current platform
  static String get firebaseAppId {
    if (kIsWeb) return firebaseAppIdWeb;
    if (Platform.isAndroid) return firebaseAppIdAndroid;
    if (Platform.isIOS) return firebaseAppIdIos;
    if (Platform.isMacOS) return firebaseAppIdIos; // macOS uses iOS bundle
    if (Platform.isWindows) return firebaseAppIdWeb; // Windows uses web config
    return _defaultAppId; // fallback
  }
  
  static String get firebaseMessagingSenderId => 
      kIsWeb ? WebEnvVars.firebaseMessagingSenderId : _getEnvVar('FIREBASE_MESSAGING_SENDER_ID', '');
  
  static String get firebaseProjectId => 
      kIsWeb ? WebEnvVars.firebaseProjectId : _getEnvVar('FIREBASE_PROJECT_ID', _defaultProjectId);
  
  static String get firebaseAuthDomain => 
      kIsWeb ? (WebEnvVars.firebaseAuthDomain.isNotEmpty ? WebEnvVars.firebaseAuthDomain : '$firebaseProjectId.firebaseapp.com') : _getEnvVar('FIREBASE_AUTH_DOMAIN', '$firebaseProjectId.firebaseapp.com');
  
  static String get firebaseStorageBucket => 
      kIsWeb ? (WebEnvVars.firebaseStorageBucket.isNotEmpty ? WebEnvVars.firebaseStorageBucket : '$firebaseProjectId.firebasestorage.app') : _getEnvVar('FIREBASE_STORAGE_BUCKET', '$firebaseProjectId.firebasestorage.app');
  
  static String get firebaseMeasurementId => 
      kIsWeb ? WebEnvVars.firebaseMeasurementId : _getEnvVar('FIREBASE_MEASUREMENT_ID', '');
  
  // Google Maps API Keys
  static String get googleMapsApiKeyAndroid => 
      kIsWeb ? WebEnvVars.googleMapsApiKeyAndroid : _getEnvVar('GOOGLE_MAPS_API_KEY_ANDROID', '');
  
  static String get googleMapsApiKeyIos => 
      kIsWeb ? WebEnvVars.googleMapsApiKeyIos : _getEnvVar('GOOGLE_MAPS_API_KEY_IOS', '');
  
  // Validation
  static bool get isConfigured {
    return firebaseApiKey.isNotEmpty &&
           firebaseAppIdWeb.isNotEmpty &&
           firebaseAppIdAndroid.isNotEmpty &&
           firebaseAppIdIos.isNotEmpty &&
           firebaseProjectId.isNotEmpty;
  }
  
  static void validateConfiguration() {
    if (!isConfigured) {
      throw Exception('''
        Firebase configuration is not properly set up!
        
        Please create a .env file with the following variables:
        - FIREBASE_API_KEY
        - FIREBASE_APP_ID_WEB
        - FIREBASE_APP_ID_ANDROID
        - FIREBASE_APP_ID_IOS
        - FIREBASE_PROJECT_ID
        - FIREBASE_MESSAGING_SENDER_ID
        - FIREBASE_AUTH_DOMAIN
        - FIREBASE_STORAGE_BUCKET
        - FIREBASE_MEASUREMENT_ID
        
        See env.example for the complete list.
      ''');
    }
  }
}
