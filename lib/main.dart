import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/spot_service.dart';
import 'package:parkour_spot/screens/splash_screen.dart';
import 'package:parkour_spot/firebase_options.dart';
import 'package:parkour_spot/services/deep_link_service.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SpotService()),
        ChangeNotifierProvider(create: (_) => DeepLinkService()..initialize()),
      ],
      child: MaterialApp(
        title: 'ParkourSpot',
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
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
