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
import 'package:flutter/foundation.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If we're already on a spot detail page, don't redirect
      if (state.matchedLocation.startsWith('/spot/') || 
          state.matchedLocation.startsWith('/s/')) {
        return null;
      }
      
      // If we're on the root but there's a path in the URI, redirect to that path
      if (state.matchedLocation == '/' && 
          state.uri.pathSegments.isNotEmpty &&
          (state.uri.path.startsWith('/spot/') || state.uri.path.startsWith('/s/'))) {
        return state.uri.path;
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
      GoRoute(
        path: '/spot/:spotId',
        builder: (context, state) {
          final spotId = state.pathParameters['spotId']!;
          return SpotDetailRoute(spotId: spotId);
        },
      ),
      // Alternative shorter route
      GoRoute(
        path: '/s/:spotId',
        builder: (context, state) {
          final spotId = state.pathParameters['spotId']!;
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
