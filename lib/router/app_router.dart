import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
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
import '../screens/admin/admin_notifications_screen.dart';
import '../screens/admin/admin_event_edit_screen.dart';
import '../screens/admin/spot_data_screen.dart';
import '../screens/admin/spot_images_screen.dart';
import '../screens/admin/event_data_screen.dart';
import '../screens/admin/event_sync_sources_screen.dart';
import '../screens/admin/admin_push_subscriptions_screen.dart';
import '../screens/admin/user_activity_metrics_screen.dart';
import '../screens/admin/audit_log_viewer_screen.dart';
import '../screens/admin/duplicate_images_screen.dart';
import '../screens/admin/missing_resized_images_screen.dart';
import '../screens/admin/duplicate_spots_screen.dart';
import '../screens/admin/duplicate_spots_results_screen.dart';
import '../screens/admin/duplicate_spots_pair_review_screen.dart';
import '../screens/admin/device_detection_screen.dart';
import '../screens/debug/support_debug_screen.dart';
import '../screens/admin/api_clients_screen.dart';
import '../screens/moderator/moderator_tools_screen.dart';
import '../screens/moderator/event_report_queue_screen.dart';
import '../screens/moderator/moderator_events_review_screen.dart';
import '../screens/moderator/moderator_duplicate_event_updates_screen.dart';
import '../screens/moderator/moderator_duplicate_spot_updates_screen.dart';
import '../screens/moderator/spot_report_queue_screen.dart';
import '../screens/events/add_event_report_screen.dart';
import '../screens/spots/spot_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../screens/spots/add_spot_screen.dart';
import '../screens/spots/edit_spot_screen.dart';
import '../screens/spots/spot_list_detail_screen.dart';
import '../screens/spots/spot_tracking_list_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profile/my_check_ins_screen.dart';
import '../screens/profile/account_settings_screen.dart';
import '../screens/profile/notifications_screen.dart';
import '../screens/profile/spot_lists_hub_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/auth_service.dart';
import '../analytics/web_analytics.dart';
import '../services/pwa_install_service.dart';

/// Router observer that tracks page views for Google Analytics
class GaObserver extends NavigatorObserver {
  static GoRouter? _router;
  static AuthService? _authService;

  static void setRouter(GoRouter router) {
    _router = router;
  }

  static void setAuthService(AuthService authService) {
    _authService = authService;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _track();
    }
  }

  void _track() {
    // Use a post-frame callback to ensure the router state has updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Get the current route path from GoRouter's state
        // This gives us the actual matched location (e.g., /us/new-york/spot-123)
        // instead of the route pattern (e.g., /:countryCode/:city/:spotId)
        final router = _router;
        if (router != null) {
          final path = router.routerDelegate.currentConfiguration.uri.path;
          WebAnalytics.trackPageView(path: path);
        } else {
          // Fallback to browser URL if router is not set yet
          final path = web.window.location.pathname;
          WebAnalytics.trackPageView(path: path);
        }
      } catch (e) {
        // Fallback to browser URL if router state is not available
        final path = web.window.location.pathname;
        WebAnalytics.trackPageView(path: path);
      }

      // Track page view for PWA install service
      try {
        PwaInstallService().trackPageView();
      } catch (e) {
        // Silent fail - PWA tracking is not critical
      }

      // Update lastActiveAt for logged-in users
      // If AuthService isn't available yet, retry after a short delay (for initial page load)
      try {
        final authService = _authService;
        if (authService == null) {
          // Retry after a short delay to allow AuthService to be set
          Future.delayed(const Duration(milliseconds: 500), () {
            final retryAuthService = _authService;
            if (retryAuthService != null && retryAuthService.isAuthenticated) {
              retryAuthService.updateLastActiveAt();
            }
          });
        } else {
          if (authService.isAuthenticated) {
            authService.updateLastActiveAt();
          }
        }
      } catch (e) {
        // Silent fail - lastActiveAt tracking is not critical
      }
    });
  }
}

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
  static final GaObserver _gaObserver = GaObserver();
  static GoRouter? _routerInstance;

  static GoRouter get router {
    _routerInstance ??= _createRouter();
    GaObserver.setRouter(_routerInstance!);
    return _routerInstance!;
  }

  /// Set the AuthService reference for lastActiveAt tracking
  static void setAuthService(AuthService authService) {
    GaObserver.setAuthService(authService);
  }

  static GoRouter _createRouter() {
    // Allow push() to update the browser URL so profile and other drill-down
    // navigation shows the correct URL (for sharing, bookmarks, etc.)
    GoRouter.optionURLReflectsImperativeAPIs = true;
    return GoRouter(
      initialLocation: '/',
      observers: [_titleObserver, _gaObserver],
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
        // Use Provider to get the AuthService instance (don't create a new one!)
        final authService = Provider.of<AuthService>(context, listen: false);
        final isAuthenticated = authService.isAuthenticated;

        // Routes that require authentication
        final protectedRoutes = [
          '/spots/add',
          '/events/add',
          '/moderator',
          '/profile/notifications',
        ];
        final location = state.matchedLocation;
        if ((protectedRoutes.contains(location) ||
                location.startsWith('/moderator/')) &&
            !isAuthenticated) {
          // Redirect to login with the intended destination
          String redirectTo;
          if (state.matchedLocation == '/spots/add' ||
              state.matchedLocation == '/events/add') {
            redirectTo = '/explore?tab=add';
          } else {
            redirectTo = state.matchedLocation;
          }
          return '/login?redirectTo=${Uri.encodeComponent(redirectTo)}';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/explore',
          builder: (context, state) {
            // Parse tab parameter from query string
            final tabParam = state.uri.queryParameters['tab'];
            int initialTab = 0;

            // listId, locateSpotId, and locateEventId are map-focused: map tab
            final hasListId =
                state.uri.queryParameters['listId']?.isNotEmpty ?? false;
            final hasLocateSpotId =
                state.uri.queryParameters['locateSpotId']?.isNotEmpty ?? false;
            final hasLocateEventId =
                state.uri.queryParameters['locateEventId']?.isNotEmpty ?? false;
            final forceMapTab =
                hasListId || hasLocateSpotId || hasLocateEventId;

            if (!forceMapTab && tabParam != null) {
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

            // Parse listId query parameter
            final listId = state.uri.queryParameters['listId'];
            final latParam = state.uri.queryParameters['lat'];
            final lngParam = state.uri.queryParameters['lng'];
            final lat = latParam != null ? double.tryParse(latParam) : null;
            final lng = lngParam != null ? double.tryParse(lngParam) : null;
            final initialAddSpotLocation = (lat != null && lng != null)
                ? gmaps.LatLng(lat, lng)
                : null;

            return ExploreScreen(
              initialTab: initialTab,
              initialLocationQuery: locationQuery,
              initialListId: listId,
              initialLocateSpotId: state.uri.queryParameters['locateSpotId'],
              initialLocateEventId: state.uri.queryParameters['locateEventId'],
              initialAddSpotLocation: initialAddSpotLocation,
            );
          },
        ),
        // Add forms
        GoRoute(
          path: '/spots/add',
          builder: (context, state) {
            final latParam = state.uri.queryParameters['lat'];
            final lngParam = state.uri.queryParameters['lng'];
            final lat = latParam != null ? double.tryParse(latParam) : null;
            final lng = lngParam != null ? double.tryParse(lngParam) : null;
            final initialLocation = (lat != null && lng != null)
                ? gmaps.LatLng(lat, lng)
                : null;
            return AddSpotScreen(initialLocation: initialLocation);
          },
        ),
        GoRoute(
          path: '/events/add',
          builder: (context, state) {
            final latParam = state.uri.queryParameters['lat'];
            final lngParam = state.uri.queryParameters['lng'];
            final lat = latParam != null ? double.tryParse(latParam) : null;
            final lng = lngParam != null ? double.tryParse(lngParam) : null;
            final initialLocation = (lat != null && lng != null)
                ? gmaps.LatLng(lat, lng)
                : null;
            final extra = state.extra;
            final initialLinkedSpot = extra is Spot ? extra : null;
            final initialSpotListSpots = extra is List<Spot>
                ? extra
                : (extra is List
                      ? extra.whereType<Spot>().toList(growable: false)
                      : null);
            return AddEventReportScreen(
              initialLocation: initialLocation,
              initialLinkedSpot: initialLinkedSpot,
              initialSpotId: state.uri.queryParameters['spotId'],
              initialSpotName: state.uri.queryParameters['spotName'],
              initialSpotListId: state.uri.queryParameters['spotListId'],
              initialSpotListName: state.uri.queryParameters['spotListName'],
              initialSpotListSpots: initialSpotListSpots?.isNotEmpty == true
                  ? initialSpotListSpots
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/profile',
          redirect: (context, state) {
            // Don't redirect child routes
            final path = state.uri.path;
            if (path == '/profile/want-to-visit' ||
                path == '/profile/visited' ||
                path == '/profile/added' ||
                path == '/profile/check-ins' ||
                path == '/profile/lists' ||
                path == '/profile/settings' ||
                path == '/profile/notifications') {
              return null;
            }
            return '/explore?tab=profile';
          },
          routes: [
            GoRoute(
              path: 'want-to-visit',
              builder: (context, state) => const SpotTrackingListScreen(
                type: SpotTrackingListType.wantToVisit,
              ),
            ),
            GoRoute(
              path: 'visited',
              builder: (context, state) => const SpotTrackingListScreen(
                type: SpotTrackingListType.visited,
              ),
            ),
            GoRoute(
              path: 'added',
              builder: (context, state) => const SpotTrackingListScreen(
                type: SpotTrackingListType.added,
              ),
            ),
            GoRoute(
              path: 'check-ins',
              builder: (context, state) => const MyCheckInsScreen(),
            ),
            GoRoute(
              path: 'lists',
              builder: (context, state) => const SpotListsHubScreen(),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => const AccountSettingsScreen(),
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/list/:listId',
          builder: (context, state) {
            final listId = state.pathParameters['listId']!;
            return SpotListDetailScreen(listId: listId);
          },
        ),
        GoRoute(
          path: '/user/:userIdOrUsername',
          builder: (context, state) {
            final userIdOrUsername = state.pathParameters['userIdOrUsername']!;
            return PublicProfileScreen(userIdOrUsername: userIdOrUsername);
          },
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
          path: '/admin/spot-data',
          builder: (context, state) => const SpotDataScreen(),
        ),
        GoRoute(
          path: '/admin/spot-images',
          builder: (context, state) => const SpotImagesScreen(),
        ),
        GoRoute(
          path: '/admin/event-data',
          builder: (context, state) => const EventDataScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/notifications',
          builder: (context, state) => const AdminNotificationsScreen(),
        ),
        GoRoute(
          path: '/admin/events',
          redirect: (context, state) => '/admin/event-sources',
        ),
        GoRoute(
          path: '/admin/events/:eventId/edit',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return AdminEventEditScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: '/admin/event-sources',
          builder: (context, state) => const EventSyncSourcesScreen(),
        ),
        GoRoute(
          path: '/admin/push-subscriptions',
          builder: (context, state) => const AdminPushSubscriptionsScreen(),
        ),
        GoRoute(
          path: '/admin/user-activity-metrics',
          builder: (context, state) => const UserActivityMetricsScreen(),
        ),
        GoRoute(
          path: '/admin/audit-log',
          builder: (context, state) => const AuditLogViewerScreen(),
        ),
        GoRoute(
          path: '/admin/duplicate-images',
          builder: (context, state) => const DuplicateImagesScreen(),
        ),
        GoRoute(
          path: '/admin/missing-resized-images',
          builder: (context, state) => const MissingResizedImagesScreen(),
        ),
        GoRoute(
          path: '/admin/device-detection',
          builder: (context, state) => const DeviceDetectionScreen(),
        ),
        GoRoute(
          path: '/admin/api-clients',
          builder: (context, state) => const ApiClientsScreen(),
        ),
        GoRoute(
          path: '/event/:eventId',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return EventDetailScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: '/moderator',
          builder: (context, state) => const ModeratorToolsScreen(),
        ),
        GoRoute(
          path: '/moderator/reports',
          builder: (context, state) => const SpotReportQueueScreen(),
        ),
        GoRoute(
          path: '/moderator/event-reports',
          builder: (context, state) => const EventReportQueueScreen(),
        ),
        GoRoute(
          path: '/moderator/events',
          builder: (context, state) => const ModeratorEventsReviewScreen(),
        ),
        GoRoute(
          path: '/moderator/duplicate-event-updates',
          builder: (context, state) =>
              const ModeratorDuplicateEventUpdatesScreen(),
        ),
        GoRoute(
          path: '/moderator/duplicate-spot-updates',
          builder: (context, state) =>
              const ModeratorDuplicateSpotUpdatesScreen(),
        ),
        GoRoute(
          path: '/moderator/duplicate-spots',
          builder: (context, state) => const DuplicateSpotsScreen(),
          routes: [
            GoRoute(
              path: ':runId',
              builder: (context, state) {
                final runId = state.pathParameters['runId']!;
                return DuplicateSpotsResultsScreen(runId: runId);
              },
              routes: [
                GoRoute(
                  path: 'pair/:pairIndex',
                  builder: (context, state) {
                    final runId = state.pathParameters['runId']!;
                    final pairIndex =
                        int.tryParse(state.pathParameters['pairIndex'] ?? '') ??
                        0;
                    return DuplicateSpotsPairReviewScreen(
                      runId: runId,
                      pairIndex: pairIndex,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Simple spot detail route: /spot/:spotId
        // Must come before location routes to ensure /spot/:spotId matches before /:countryCode/:city
        GoRoute(
          path: '/spot/:spotId',
          builder: (context, state) {
            final spotId = state.pathParameters['spotId']!;
            final imageIndexParam = state.uri.queryParameters['imageIndex'];
            final imageIndex = imageIndexParam != null
                ? int.tryParse(imageIndexParam)
                : null;
            return SpotDetailRoute(
              spotId: spotId,
              initialImageIndex: imageIndex,
            );
          },
          routes: [
            // Edit route: /spot/:spotId/edit
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final spotId = state.pathParameters['spotId']!;
                final spot = state.extra is Spot ? state.extra as Spot : null;
                return EditSpotRoute(spotId: spotId, spot: spot);
              },
            ),
          ],
        ),
        // Hidden support page (not linked in UI); must be before /:countryCode routes
        GoRoute(
          path: '/debug',
          builder: (context, state) => const SupportDebugScreen(),
        ),
        // Location routes - must come after specific routes like /spot/:spotId
        // Route for /:countryCode/:city (e.g., /gb/london)
        // Note: GoRouter will only match this if there are exactly 2 path segments
        GoRoute(
          path: '/:countryCode/:city',
          redirect: (context, state) {
            final countryCode = state.pathParameters['countryCode']!;

            // Validate that countryCode is 2 letters
            if (countryCode.length != 2 ||
                !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
              return '/explore';
            }

            // Check if country code actually exists
            final countryName = _getCountryNameFromCode(
              countryCode.toUpperCase(),
            );
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
            final countryName = _getCountryNameFromCode(
              countryCode.toUpperCase(),
            )!;

            // Decode city name (handle URL encoding)
            final decodedCity = Uri.decodeComponent(city);
            // Capitalize first letter of each word
            final cityName = decodedCity
                .split(' ')
                .map((word) {
                  if (word.isEmpty) return word;
                  return word[0].toUpperCase() +
                      word.substring(1).toLowerCase();
                })
                .join(' ');

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
            if (countryCode.length != 2 ||
                !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
              return '/explore';
            }

            // Check if country code actually exists
            final countryName = _getCountryNameFromCode(
              countryCode.toUpperCase(),
            );
            if (countryName == null) {
              return '/explore';
            }

            // Valid country code, proceed to builder
            return null;
          },
          builder: (context, state) {
            final countryCode = state.pathParameters['countryCode']!;

            // Get country name (we know it exists from redirect check)
            final countryName = _getCountryNameFromCode(
              countryCode.toUpperCase(),
            )!;

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
            if (countryCode.length != 2 ||
                !RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode)) {
              // If not a valid country code, redirect to explore
              return const ExploreScreen();
            }

            final imageIndexParam = state.uri.queryParameters['imageIndex'];
            final imageIndex = imageIndexParam != null
                ? int.tryParse(imageIndexParam)
                : null;
            return SpotDetailRoute(
              spotId: spotId,
              initialImageIndex: imageIndex,
            );
          },
          routes: [
            // Edit route: /:countryCode/:city/:spotId/edit
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final spotId = state.pathParameters['spotId']!;
                final spot = state.extra is Spot ? state.extra as Spot : null;
                return EditSpotRoute(spotId: spotId, spot: spot);
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
  }

  /// Check if the given path matches the spot URL format
  /// Format: /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt; where xx is 2 letters
  static bool _isSpotUrl(String path) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length == 3) {
      final countryCode = segments[0];
      return countryCode.length == 2 &&
          RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode);
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

class SpotDetailRoute extends StatefulWidget {
  final String spotId;
  final int? initialImageIndex;

  const SpotDetailRoute({
    super.key,
    required this.spotId,
    this.initialImageIndex,
  });

  @override
  State<SpotDetailRoute> createState() => _SpotDetailRouteState();
}

class _SpotDetailRouteState extends State<SpotDetailRoute> {
  Future<Spot?>? _spotFuture;

  @override
  void initState() {
    super.initState();
    _spotFuture = Provider.of<SpotService>(
      context,
      listen: false,
    ).getSpotById(widget.spotId);
  }

  @override
  void didUpdateWidget(covariant SpotDetailRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotId != widget.spotId) {
      _spotFuture = Provider.of<SpotService>(
        context,
        listen: false,
      ).getSpotById(widget.spotId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpotService>(
      builder: (context, spotService, child) {
        return FutureBuilder<Spot?>(
          future: _spotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        l10n.spotDetailRouteErrorLoading,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.spotDetailRouteTryAgainLater,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.spotDetailRouteNotFound),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(l10n.spotDetailRouteGoToExplore),
                      ),
                    ],
                  ),
                ),
              );
            }

            final spot = snapshot.data!;
            return SpotDetailScreen(
              spot: spot,
              initialImageIndex: widget.initialImageIndex,
            );
          },
        );
      },
    );
  }
}

class EditSpotRoute extends StatelessWidget {
  final String spotId;
  final Spot? spot;

  const EditSpotRoute({super.key, required this.spotId, this.spot});

  @override
  Widget build(BuildContext context) =>
      _EditSpotRouteContent(spotId: spotId, providedSpot: spot);
}

class _EditSpotRouteContent extends StatefulWidget {
  final String spotId;
  final Spot? providedSpot;

  const _EditSpotRouteContent({
    required this.spotId,
    required this.providedSpot,
  });

  @override
  State<_EditSpotRouteContent> createState() => _EditSpotRouteContentState();
}

class _EditSpotRouteContentState extends State<_EditSpotRouteContent> {
  Future<Spot?>? _spotFuture;
  Spot? _resolvedSpot;

  @override
  void initState() {
    super.initState();
    _resolvedSpot = widget.providedSpot;
    if (_resolvedSpot == null) {
      _spotFuture = Provider.of<SpotService>(
        context,
        listen: false,
      ).getSpotById(widget.spotId);
    }
  }

  @override
  void didUpdateWidget(covariant _EditSpotRouteContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providedSpot != null && _resolvedSpot == null) {
      _resolvedSpot = widget.providedSpot;
    }
    if (oldWidget.spotId != widget.spotId) {
      _resolvedSpot = widget.providedSpot;
      if (_resolvedSpot == null) {
        _spotFuture = Provider.of<SpotService>(
          context,
          listen: false,
        ).getSpotById(widget.spotId);
      } else {
        _spotFuture = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSpot = _resolvedSpot;
    if (resolvedSpot != null) {
      return EditSpotScreen(
        key: ValueKey('edit-${resolvedSpot.id}'),
        spot: resolvedSpot,
      );
    }

    return Consumer<SpotService>(
      builder: (context, spotService, child) {
        return FutureBuilder<Spot?>(
          future: _spotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
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

            if (!snapshot.hasData || snapshot.data == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
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
            return EditSpotScreen(key: ValueKey('edit-${spot.id}'), spot: spot);
          },
        );
      },
    );
  }
}
