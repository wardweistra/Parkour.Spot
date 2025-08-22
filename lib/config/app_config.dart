import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _defaultApiKey = 'YOUR_API_KEY_HERE';
  static const String _defaultAppId = 'YOUR_APP_ID_HERE';
  static const String _defaultProjectId = 'YOUR_PROJECT_ID_HERE';
  
  // Firebase Configuration
  static String get firebaseApiKey => 
      Platform.environment['FIREBASE_API_KEY'] ?? _defaultApiKey;
  
  // Platform-specific App IDs
  static String get firebaseAppIdWeb => 
      Platform.environment['FIREBASE_APP_ID_WEB'] ?? _defaultAppId;
  
  static String get firebaseAppIdAndroid => 
      Platform.environment['FIREBASE_APP_ID_ANDROID'] ?? _defaultAppId;
  
  static String get firebaseAppIdIos => 
      Platform.environment['FIREBASE_APP_ID_IOS'] ?? _defaultAppId;
  
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
      Platform.environment['FIREBASE_MESSAGING_SENDER_ID'] ?? '999200005209';
  
  static String get firebaseProjectId => 
      Platform.environment['FIREBASE_PROJECT_ID'] ?? _defaultProjectId;
  
  static String get firebaseAuthDomain => 
      Platform.environment['FIREBASE_AUTH_DOMAIN'] ?? '${firebaseProjectId}.firebaseapp.com';
  
  static String get firebaseStorageBucket => 
      Platform.environment['FIREBASE_STORAGE_BUCKET'] ?? '${firebaseProjectId}.firebasestorage.app';
  
  static String get firebaseMeasurementId => 
      Platform.environment['FIREBASE_MEASUREMENT_ID'] ?? 'G-861J61HFR8';
  
  // Google Maps API Keys
  static String get googleMapsApiKeyAndroid => 
      Platform.environment['GOOGLE_MAPS_API_KEY_ANDROID'] ?? 'YOUR_ANDROID_MAPS_KEY_HERE';
  
  static String get googleMapsApiKeyIos => 
      Platform.environment['GOOGLE_MAPS_API_KEY_IOS'] ?? 'YOUR_IOS_MAPS_KEY_HERE';
  
  // Validation
  static bool get isConfigured {
    return firebaseApiKey != _defaultApiKey &&
           firebaseAppIdWeb != _defaultAppId &&
           firebaseAppIdAndroid != _defaultAppId &&
           firebaseAppIdIos != _defaultAppId &&
           firebaseProjectId != _defaultProjectId;
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
