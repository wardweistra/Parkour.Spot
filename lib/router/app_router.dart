import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/spots/spot_detail_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/spots/add_spot_screen.dart';
import '../screens/spots/spots_list_screen.dart';
import '../screens/spots/map_screen.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/auth_service.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If we're already on a spot detail page, don't redirect
      if (_isSpotUrl(state.matchedLocation)) {
        return null;
      }
      
      // If we're on the root but there's a path in the URI, redirect to that path
      if (state.matchedLocation == '/' && 
          state.uri.pathSegments.isNotEmpty &&
          _isSpotUrl(state.uri.path)) {
        return state.uri.path;
      }
      
      // Check authentication for protected routes
      final authService = AuthService();
      final isAuthenticated = authService.isAuthenticated;
      
      // Routes that require authentication
      final protectedRoutes = ['/profile', '/spots/add'];
      if (protectedRoutes.contains(state.matchedLocation) && !isAuthenticated) {
        return '/login';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/spots',
        builder: (context, state) => const SpotsListScreen(),
      ),
      GoRoute(
        path: '/spots/add',
        builder: (context, state) => const AddSpotScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      // Spot detail route: /nl/amsterdam/&lt;spot-id&gt; or any /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
      GoRoute(
        path: '/:countryCode/:city/:spotId',
        builder: (context, state) {
          final spotId = state.pathParameters['spotId']!;
          final countryCode = state.pathParameters['countryCode']!;
          // city parameter is available but not currently used
          // final city = state.pathParameters['city']!;
          
          // Validate that countryCode is 2 letters
          if (countryCode.length != 2 || !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
            // If not a valid country code, redirect to home
            return const HomeScreen();
          }
          
          return SpotDetailRoute(spotId: spotId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you\'re looking for doesn\'t exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
  
  /// Check if the given path matches the spot URL format
  /// Format: /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt; where xx is 2 letters
  static bool _isSpotUrl(String path) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.length == 3) {
      final countryCode = segments[0];
      return countryCode.length == 2 && RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode);
    }
    return false;
  }
}

class SpotDetailRoute extends StatelessWidget {
  final String spotId;
  
  const SpotDetailRoute({super.key, required this.spotId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Spot?>(
      future: SpotService().getSpotById(spotId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading spot',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Spot not found'),
                ],
              ),
            ),
          );
        }

        final spot = snapshot.data!;
        return SpotDetailScreen(spot: spot);
      },
    );
  }
}
