import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/sync_sources_screen.dart';
import '../screens/admin/geocoding_admin_screen.dart';
import '../screens/admin/geohash_admin_screen.dart';
import '../screens/admin/lat_lng_migration_screen.dart';
import '../screens/spots/spot_detail_screen.dart';
import '../screens/auth/login_screen.dart';
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
        // Redirect to login with the intended destination
        String redirectTo = state.matchedLocation;
        if (state.matchedLocation == '/profile') {
          redirectTo = '/home?tab=profile';
        } else if (state.matchedLocation == '/spots/add') {
          redirectTo = '/home?tab=add';
        }
        return '/login?redirectTo=${Uri.encodeComponent(redirectTo)}';
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
        builder: (context, state) {
          // Parse tab parameter from query string
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          
          if (tabParam != null) {
            switch (tabParam) {
              case 'add':
                initialTab = 1;
                break;
              case 'profile':
                initialTab = 2;
                break;
              default:
                initialTab = 0;
            }
          }
          
          return HomeScreen(initialTab: initialTab);
        },
      ),
      // Individual tab routes that redirect to home with tab parameter
      GoRoute(
        path: '/spots/add',
        redirect: (context, state) => '/home?tab=add',
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/home?tab=profile',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Admin routes (screen will self-guard on admin status)
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/admin/sources',
        builder: (context, state) => const SyncSourcesScreen(),
      ),
      GoRoute(
        path: '/admin/geocoding',
        builder: (context, state) => const GeocodingAdminScreen(),
      ),
      GoRoute(
        path: '/admin/geohash',
        builder: (context, state) => const GeohashAdminScreen(),
      ),
      GoRoute(
        path: '/admin/lat-lng-migration',
        builder: (context, state) => const LatLngMigrationScreen(),
      ),
      // Simple spot detail route: /spot/:spotId
      GoRoute(
        path: '/spot/:spotId',
        builder: (context, state) {
          final spotId = state.pathParameters['spotId']!;
          return SpotDetailRoute(spotId: spotId);
        },
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
    return Consumer<SpotService>(
      builder: (context, spotService, child) {
        // Ensure spots are loaded if they haven't been yet
        if (spotService.spots.isEmpty && !spotService.isLoading) {
          // Trigger spots loading if not already loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            spotService.fetchSpots();
          });
        }
        
        return FutureBuilder<Spot?>(
          future: spotService.getSpotById(spotId),
          builder: (context, snapshot) {
            // Debug logging
            if (kDebugMode) {
              print('SpotDetailRoute: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
              print('SpotDetailRoute: spots count=${spotService.spots.length}, isLoading=${spotService.isLoading}');
            }
            
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
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Spot not found'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Go Home'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final spot = snapshot.data!;
            return SpotDetailScreen(spot: spot);
          },
        );
      },
    );
  }
}
