import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/spot_service.dart';
import 'package:parkour_spot/router/app_router.dart';
import 'package:parkour_spot/firebase_options.dart';
import 'package:web/web.dart' as web;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ParkourSpotApp());
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
        ChangeNotifierProvider(create: (_) => SpotService()),
      ],
      child: MaterialApp.router(
        title: 'ParkourSpot',
        routerConfig: AppRouter.router,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
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
      final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
      final countryCode = segments[0];
      return countryCode.length == 2 && RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode);
    }
    
    return false;
  }
}
