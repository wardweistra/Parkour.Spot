import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/spot_service.dart';
import 'package:parkour_spot/services/spot_report_service.dart';
import 'package:parkour_spot/services/sync_source_service.dart';
import 'package:parkour_spot/services/search_state_service.dart';
import 'package:parkour_spot/services/geocoding_service.dart';
import 'package:parkour_spot/services/user_management_service.dart';
import 'package:parkour_spot/services/snackbar_service.dart';
import 'package:parkour_spot/router/app_router.dart';
import 'package:parkour_spot/firebase_options.dart';
import 'package:parkour_spot/config/app_config.dart';
import 'package:web/web.dart' as web;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs instead of hash-based routing
  usePathUrlStrategy();

  // Validate configuration before initializing Firebase
  AppConfig.validateConfiguration();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect to emulators if USE_EMULATOR is set
  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    await _connectToEmulators();
  }

  runApp(const ParkourSpotApp());
}

/// Connect Firebase services to local emulators
Future<void> _connectToEmulators() async {
  // Note: For web, we use localhost. For other platforms, use 10.0.2.2 for Android emulator
  const host = 'localhost';
  
  try {
    // Connect Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8082);
    
    // Connect Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    
    // Connect Storage emulator
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
    
    // Connect Functions emulator
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(host, 5001);
    
    debugPrint('✅ Connected to Firebase Emulators');
    debugPrint('   - Firestore: $host:8082');
    debugPrint('   - Auth: $host:9099');
    debugPrint('   - Storage: $host:9199');
    debugPrint('   - Functions: $host:5001');
  } catch (e) {
    debugPrint('⚠️  Error connecting to emulators: $e');
    debugPrint('   Make sure Firebase emulators are running!');
  }
}

class ParkourSpotApp extends StatelessWidget {
  const ParkourSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Web-specific: Check for deep link on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialDeepLink();
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserManagementService()),
        ChangeNotifierProvider(create: (_) => SpotService()),
        ChangeNotifierProvider(create: (_) => SyncSourceService()),
        ChangeNotifierProvider(
          create: (_) => SearchStateService()..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => GeocodingService()),
        Provider(create: (_) => SpotReportService()),
      ],
      child: MaterialApp.router(
        title: 'Parkour·Spot',
        routerConfig: AppRouter.router,
        scaffoldMessengerKey: SnackbarService.messengerKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007FA8),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007FA8),
            brightness: Brightness.dark,
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  void _checkInitialDeepLink() {
    try {
      final browserUrl = web.window.location.href;
      final browserPath = Uri.parse(browserUrl).path;

      if (_isSpotUrl(browserPath)) {
        // Use a small delay to ensure the router is ready
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            final router = AppRouter.router;
            router.go(browserPath);
          } catch (e) {
            // Silent fail - router might not be ready yet
          }
        });
      }
    } catch (e) {
      // Silent fail - not critical for app functionality
    }
  }

  /// Check if the given path is a spot URL
  /// Supports format: /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
  /// where xx is a 2-letter country code
  bool _isSpotUrl(String path) {
    // Format: /nl/amsterdam/&lt;spot-id&gt; or any /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
    if (path.split('/').where((segment) => segment.isNotEmpty).length == 3) {
      final segments = path
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      final countryCode = segments[0];
      return countryCode.length == 2 &&
          RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode);
    }

    return false;
  }
}
