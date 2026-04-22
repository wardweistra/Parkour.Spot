import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/utils/web_meta_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:parkour_spot/services/api_client_service.dart';
import 'package:parkour_spot/services/search_state_service.dart';
import 'package:parkour_spot/services/geocoding_service.dart';
import 'package:parkour_spot/services/jumpflix_service.dart';
import 'package:parkour_spot/services/user_management_service.dart';
import 'package:parkour_spot/services/admin_notifications_service.dart';
import 'package:parkour_spot/services/admin_push_subscriptions_service.dart';
import 'package:parkour_spot/services/snackbar_service.dart';
import 'package:parkour_spot/services/spot_list_service.dart';
import 'package:parkour_spot/services/saved_spot_list_service.dart';
import 'package:parkour_spot/services/spot_tracking_service.dart';
import 'package:parkour_spot/services/spot_check_in_service.dart';
import 'package:parkour_spot/services/spot_training_plan_service.dart';
import 'package:parkour_spot/services/feature_access_service.dart';
import 'package:parkour_spot/services/pwa_install_service.dart';
import 'package:parkour_spot/services/user_profile_service.dart';
import 'package:parkour_spot/services/user_locations_of_interest_service.dart';
import 'package:parkour_spot/services/user_notification_service.dart';
import 'package:parkour_spot/services/locale_preferences_service.dart';
import 'package:parkour_spot/services/web_push_subscription_service.dart';
import 'package:parkour_spot/router/app_router.dart';
import 'package:parkour_spot/firebase_options.dart';
import 'package:parkour_spot/config/app_config.dart';
import 'package:parkour_spot/analytics/web_analytics.dart';
import 'package:web/web.dart' as web;
import 'package:google_fonts/google_fonts.dart';

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

  if (kIsWeb) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      final title = n?.title ?? 'Notification';
      final body = n?.body;
      SnackbarService.showFcmForeground(title, body);
    });
  }

  runApp(const ParkourSpotApp());

  // Initialize Google Analytics
  WebAnalytics.init();
  WebAnalytics.trackEvent('app_start', {'platform': 'web'});
}

/// Connect Firebase services to local emulators
Future<void> _connectToEmulators() async {
  // Note: For web, we use 127.0.0.1 to match emulator URLs. For other platforms, use 10.0.2.2 for Android emulator
  const host = '127.0.0.1';

  // Emulator port configuration
  const firestorePort = 8082;
  const authPort = 9099;
  const storagePort = 9199;
  const functionsPort = 5001;

  try {
    // Connect Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);

    // Connect Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);

    // Connect Storage emulator
    FirebaseStorage.instance.useStorageEmulator(host, storagePort);

    // Connect Functions emulator
    FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).useFunctionsEmulator(host, functionsPort);

    debugPrint('✅ Connected to Firebase Emulators');
    debugPrint('   - Firestore: $host:$firestorePort');
    debugPrint('   - Auth: $host:$authPort');
    debugPrint('   - Storage: $host:$storagePort');
    debugPrint('   - Functions: $host:$functionsPort');
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
        ChangeNotifierProvider(
          create: (_) {
            final authService = AuthService();
            // Set AuthService reference in router observer for lastActiveAt tracking
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppRouter.setAuthService(authService);
            });
            return authService;
          },
        ),
        ChangeNotifierProvider(create: (_) => UserManagementService()),
        ChangeNotifierProvider(create: (_) => AdminNotificationsService()),
        ChangeNotifierProvider(create: (_) => AdminPushSubscriptionsService()),
        ChangeNotifierProvider(create: (_) => SpotService()),
        ChangeNotifierProvider(create: (_) => SyncSourceService()),
        ChangeNotifierProvider(create: (_) => ApiClientService()),
        ChangeNotifierProvider(
          create: (_) => SearchStateService()..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => GeocodingService()),
        ChangeNotifierProvider(create: (_) => JumpflixService()),
        Provider(create: (_) => SpotReportService()),
        ChangeNotifierProxyProvider<AuthService, SpotListService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            final featureAccessService = FeatureAccessService(authService);
            return SpotListService(authService, featureAccessService);
          },
          update: (context, authService, previous) {
            final featureAccessService = FeatureAccessService(authService);
            return previous ??
                SpotListService(authService, featureAccessService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SavedSpotListService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return SavedSpotListService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? SavedSpotListService(authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SpotTrackingService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return SpotTrackingService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? SpotTrackingService(authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SpotCheckInService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            final tracking = Provider.of<SpotTrackingService>(
              context,
              listen: false,
            );
            return SpotCheckInService(authService, tracking);
          },
          update: (context, authService, previous) {
            final tracking = Provider.of<SpotTrackingService>(
              context,
              listen: false,
            );
            return previous ?? SpotCheckInService(authService, tracking);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SpotTrainingPlanService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return SpotTrainingPlanService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? SpotTrainingPlanService(authService);
          },
        ),
        ChangeNotifierProvider(
          create: (_) => PwaInstallService()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => UserProfileService()),
        ChangeNotifierProxyProvider<
          AuthService,
          UserLocationsOfInterestService
        >(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return UserLocationsOfInterestService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? UserLocationsOfInterestService(authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, UserNotificationService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return UserNotificationService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? UserNotificationService(authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, WebPushSubscriptionService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            final service = WebPushSubscriptionService();
            unawaited(service.syncAuth(authService));
            return service;
          },
          update: (context, authService, previous) {
            final service = previous ?? WebPushSubscriptionService();
            unawaited(service.syncAuth(authService));
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, LocalePreferencesService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return LocalePreferencesService(authService)..loadFromStorage();
          },
          update: (context, authService, previous) {
            return previous ?? LocalePreferencesService(authService);
          },
        ),
      ],
      child: _EagerWebPushInit(
        child: Consumer<LocalePreferencesService>(
          builder: (context, localePrefs, _) {
            return MaterialApp.router(
              onGenerateTitle: (_) => WebMetaUtils.defaultTitle,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: localePrefs.locale,
              routerConfig: AppRouter.router,
              scaffoldMessengerKey: SnackbarService.messengerKey,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF007FA8),
                  brightness: Brightness.light,
                ),
                textTheme: GoogleFonts.fredokaTextTheme(),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF007FA8),
                  brightness: Brightness.dark,
                ),
                textTheme: GoogleFonts.fredokaTextTheme(
                  ThemeData.dark().textTheme,
                ),
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
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

/// Ensures [WebPushSubscriptionService] is built on web after the first frame.
///
/// `Provider` is lazy: nothing ran push sync until something read this service
/// (e.g. Settings). Touching it once here makes startup logs and `refresh()`
/// run on cold load.
class _EagerWebPushInit extends StatefulWidget {
  const _EagerWebPushInit({required this.child});

  final Widget child;

  @override
  State<_EagerWebPushInit> createState() => _EagerWebPushInitState();
}

class _EagerWebPushInitState extends State<_EagerWebPushInit> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Provider.of<WebPushSubscriptionService>(context, listen: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
