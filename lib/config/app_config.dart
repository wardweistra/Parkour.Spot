import 'package:flutter/foundation.dart' show kIsWeb;

/// Compile-time environment variables (from `--dart-define` / `.env` scripts).
class FirebaseEnvVars {
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseAppIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
  );
  static const String firebaseAppIdAndroid = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const String firebaseWebPushVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_PUSH_VAPID_KEY',
  );
}

class AppConfig {
  // Default Map Center Coordinates
  static const double defaultMapCenterLat = 48.629828;
  static const double defaultMapCenterLng = 2.441781999999999;

  // Firebase Configuration
  static String get firebaseApiKey => FirebaseEnvVars.firebaseApiKey;

  // Platform-specific App IDs
  static String get firebaseAppIdWeb => FirebaseEnvVars.firebaseAppIdWeb;

  static String get firebaseAppIdAndroid =>
      FirebaseEnvVars.firebaseAppIdAndroid;

  static String get firebaseMessagingSenderId =>
      FirebaseEnvVars.firebaseMessagingSenderId;

  static String get firebaseProjectId => FirebaseEnvVars.firebaseProjectId;

  static String get firebaseAuthDomain =>
      FirebaseEnvVars.firebaseAuthDomain.isNotEmpty
      ? FirebaseEnvVars.firebaseAuthDomain
      : 'parkour.spot';

  static String get firebaseStorageBucket =>
      FirebaseEnvVars.firebaseStorageBucket.isNotEmpty
      ? FirebaseEnvVars.firebaseStorageBucket
      : '$firebaseProjectId.firebasestorage.app';

  static String get firebaseMeasurementId =>
      FirebaseEnvVars.firebaseMeasurementId;

  static String get firebaseWebPushVapidKey =>
      FirebaseEnvVars.firebaseWebPushVapidKey;

  // Validation
  static bool get isConfigured {
    final hasCore =
        firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
    if (!hasCore) return false;
    if (kIsWeb) return firebaseAppIdWeb.isNotEmpty;
    return firebaseAppIdAndroid.isNotEmpty;
  }

  static void validateConfiguration() {
    if (!isConfigured) {
      throw Exception('''
        Firebase configuration is not properly set up!
        
        Please create a .env file with the following variables:
        - FIREBASE_API_KEY
        - FIREBASE_APP_ID_WEB (web builds)
        - FIREBASE_APP_ID_ANDROID (Android builds)
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
