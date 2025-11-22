import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'package:sealed_countries/sealed_countries.dart';
import '../screens/splash_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/sync_sources_screen.dart';
import '../screens/admin/geocoding_admin_screen.dart';
import '../screens/admin/spot_management_screen.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/urbn_migration_screen.dart';
import '../screens/admin/audit_log_viewer_screen.dart';
import '../screens/moderator/moderator_tools_screen.dart';
import '../screens/moderator/spot_report_queue_screen.dart';
import '../screens/spots/spot_detail_screen.dart';
import '../screens/spots/edit_spot_screen.dart';
import '../screens/auth/login_screen.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/auth_service.dart';

/// Router observer that updates the document title based on the current route
class TitleObserver extends NavigatorObserver {
  static const String defaultTitle = 'Parkour·Spot';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateTitle(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateTitle(previousRoute);
    } else {
      _setTitle(defaultTitle);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateTitle(newRoute);
    } else {
      _setTitle(defaultTitle);
    }
  }

  void _updateTitle(Route<dynamic> route) {
    // Title updates for spot pages are handled in SpotDetailScreen
    // This observer handles default titles for other routes
    final routeSettings = route.settings;
    if (routeSettings.name != null && !_isSpotRoute(routeSettings.name!)) {
      _setTitle(defaultTitle);
    }
  }

  bool _isSpotRoute(String routeName) {
    // Check if this is a spot detail route
    return routeName.contains('/spot/') || 
           RegExp(r'^/[a-z]{2}/[^/]+/[^/]+$').hasMatch(routeName);
  }

  void _setTitle(String title) {
    if (kIsWeb) {
      web.document.title = title;
    }
  }
}

class AppRouter {
  static final TitleObserver _titleObserver = TitleObserver();
  
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    observers: [_titleObserver],
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
      final protectedRoutes = ['/spots/add', '/moderator'];
      if (protectedRoutes.contains(state.matchedLocation) && !isAuthenticated) {
        // Redirect to login with the intended destination
        String redirectTo;
        if (state.matchedLocation == '/spots/add') {
          redirectTo = '/explore?tab=add';
        } else {
          redirectTo = state.matchedLocation;
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
        path: '/explore',
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
          
          // Parse location query parameter
          final locationQuery = state.uri.queryParameters['location'];
          
          return ExploreScreen(
            initialTab: initialTab,
            initialLocationQuery: locationQuery,
          );
        },
      ),
      // Individual tab routes that redirect to explore with tab parameter
      GoRoute(
        path: '/spots/add',
        redirect: (context, state) => '/explore?tab=add',
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/explore?tab=profile',
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
          path: '/admin/spot-management',
          builder: (context, state) => const SpotManagementScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/urbn-migration',
          builder: (context, state) => const UrbnMigrationScreen(),
        ),
        GoRoute(
          path: '/admin/audit-log',
          builder: (context, state) => const AuditLogViewerScreen(),
        ),
      GoRoute(
        path: '/moderator',
        builder: (context, state) => const ModeratorToolsScreen(),
        routes: [
          GoRoute(
            path: 'reports',
            builder: (context, state) => const SpotReportQueueScreen(),
          ),
        ],
      ),
      // Simple spot detail route: /spot/:spotId
      // Must come before location routes to ensure /spot/:spotId matches before /:countryCode/:city
      GoRoute(
        path: '/spot/:spotId',
        builder: (context, state) {
          final spotId = state.pathParameters['spotId']!;
          return SpotDetailRoute(spotId: spotId);
        },
        routes: [
          // Edit route: /spot/:spotId/edit
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final spot = state.extra as Spot;
              return EditSpotScreen(spot: spot);
            },
          ),
        ],
      ),
      // Location routes - must come after specific routes like /spot/:spotId
      // Route for /:countryCode/:city (e.g., /gb/london)
      // Note: GoRouter will only match this if there are exactly 2 path segments
      GoRoute(
        path: '/:countryCode/:city',
        redirect: (context, state) {
          final countryCode = state.pathParameters['countryCode']!;
          
          // Validate that countryCode is 2 letters
          if (countryCode.length != 2 || !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
            return '/explore';
          }
          
          // Check if country code actually exists
          final countryName = _getCountryNameFromCode(countryCode.toUpperCase());
          if (countryName == null) {
            return '/explore';
          }
          
          // Valid country code, proceed to builder
          return null;
        },
        builder: (context, state) {
          final countryCode = state.pathParameters['countryCode']!;
          final city = state.pathParameters['city']!;
          
          // Get country name (we know it exists from redirect check)
          final countryName = _getCountryNameFromCode(countryCode.toUpperCase())!;
          
          // Decode city name (handle URL encoding)
          final decodedCity = Uri.decodeComponent(city);
          // Capitalize first letter of each word
          final cityName = decodedCity.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }).join(' ');
          
          // Build location query: "City, Country Name" (e.g., "Amsterdam, Netherlands")
          final locationQuery = '$cityName, $countryName';
          
          return ExploreScreen(initialLocationQuery: locationQuery);
        },
      ),
      // Route for /:countryCode (e.g., /gb)
      GoRoute(
        path: '/:countryCode',
        redirect: (context, state) {
          final countryCode = state.pathParameters['countryCode']!;
          
          // Validate that countryCode is 2 letters
          if (countryCode.length != 2 || !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
            return '/explore';
          }
          
          // Check if country code actually exists
          final countryName = _getCountryNameFromCode(countryCode.toUpperCase());
          if (countryName == null) {
            return '/explore';
          }
          
          // Valid country code, proceed to builder
          return null;
        },
        builder: (context, state) {
          final countryCode = state.pathParameters['countryCode']!;
          
          // Get country name (we know it exists from redirect check)
          final countryName = _getCountryNameFromCode(countryCode.toUpperCase())!;
          
          // Use the country name for the location query
          final locationQuery = countryName;
          
          return ExploreScreen(initialLocationQuery: locationQuery);
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
            // If not a valid country code, redirect to explore
            return const ExploreScreen();
          }
          
          return SpotDetailRoute(spotId: spotId);
        },
        routes: [
          // Edit route: /:countryCode/:city/:spotId/edit
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final spot = state.extra as Spot;
              return EditSpotScreen(spot: spot);
            },
          ),
        ],
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
              child: const Text('Go to Explore'),
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
  
  /// Get country name from ISO 3166-1 alpha-2 country code
  /// Returns null if not found (will fall back to country code)
  static String? _getCountryNameFromCode(String code) {
    // Normalize code to uppercase for lookup (ISO 3166-1 alpha-2 codes are uppercase)
    final normalizedCode = code.toUpperCase();
    
    // Use the nullable runtime-safe method to find country by ISO 3166-1 alpha-2 code
    final country = WorldCountry.maybeFromCodeShort(normalizedCode);
    
    if (country != null) {
      // Return the English common name
      return country.name.common;
    }
    
    // If lookup fails, return null
    return null;
  }
}

class SpotDetailRoute extends StatelessWidget {
  final String spotId;
  
  const SpotDetailRoute({super.key, required this.spotId});


  @override
  Widget build(BuildContext context) {
    return Consumer<SpotService>(
      builder: (context, spotService, child) {
        // Always fetch the individual spot directly since we no longer maintain a global spots list
        Future<Spot?> spotFuture = spotService.getSpotById(spotId);
        
        return FutureBuilder<Spot?>(
          future: spotFuture,
          builder: (context, snapshot) {
            // Debug logging
            if (kDebugMode) {
              print('SpotDetailRoute: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
              print('SpotDetailRoute: isLoading=${spotService.isLoading}');
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
                        onPressed: () => context.go('/explore'),
                        child: const Text('Go to Explore'),
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
