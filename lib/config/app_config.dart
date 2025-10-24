import 'package:flutter/foundation.dart';

// Web-specific environment variable getters (const for compile-time evaluation)
class WebEnvVars {
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const String firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String firebaseMeasurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
}

class AppConfig {
  static const String _defaultApiKey = '';
  static const String _defaultAppId = '';
  static const String _defaultProjectId = '';
  
  // Default Map Center Coordinates
  static const double defaultMapCenterLat = 48.629828;
  static const double defaultMapCenterLng = 2.441781999999999;
  
  // Firebase Configuration
  static String get firebaseApiKey => WebEnvVars.firebaseApiKey;
  
  // Platform-specific App IDs
  static String get firebaseAppIdWeb => WebEnvVars.firebaseAppIdWeb;
  
  static String get firebaseMessagingSenderId => WebEnvVars.firebaseMessagingSenderId;
  
  static String get firebaseProjectId => WebEnvVars.firebaseProjectId;
  
  static String get firebaseAuthDomain => 
      WebEnvVars.firebaseAuthDomain.isNotEmpty ? WebEnvVars.firebaseAuthDomain : '$firebaseProjectId.firebaseapp.com';
  
  static String get firebaseStorageBucket => 
      WebEnvVars.firebaseStorageBucket.isNotEmpty ? WebEnvVars.firebaseStorageBucket : '$firebaseProjectId.firebasestorage.app';
  
  static String get firebaseMeasurementId => WebEnvVars.firebaseMeasurementId;
  
  // Validation
  static bool get isConfigured {
    return firebaseApiKey.isNotEmpty &&
           firebaseAppIdWeb.isNotEmpty &&
           firebaseProjectId.isNotEmpty;
  }
  
  static void validateConfiguration() {
    if (!isConfigured) {
      throw Exception('''
        Firebase configuration is not properly set up!
        
        Please create a .env file with the following variables:
        - FIREBASE_API_KEY
        - FIREBASE_APP_ID_WEB
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
