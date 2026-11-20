import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:material_ui/material_ui.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/utils/web_meta_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/event_map_service.dart';
import 'package:parkour_spot/services/community_activity_service.dart';
import 'package:parkour_spot/services/spot_service.dart';
import 'package:parkour_spot/services/spot_report_service.dart';
import 'package:parkour_spot/services/event_report_service.dart';
import 'package:parkour_spot/services/sync_source_service.dart';
import 'package:parkour_spot/services/api_client_service.dart';
import 'package:parkour_spot/services/search_state_service.dart';
import 'package:parkour_spot/services/geocoding_service.dart';
import 'package:parkour_spot/services/jumpflix_service.dart';
import 'package:parkour_spot/services/user_management_service.dart';
import 'package:parkour_spot/services/admin_notifications_service.dart';
import 'package:parkour_spot/services/admin_events_service.dart';
import 'package:parkour_spot/services/event_sync_source_service.dart';
import 'package:parkour_spot/services/admin_push_subscriptions_service.dart';
import 'package:parkour_spot/services/snackbar_service.dart';
import 'package:parkour_spot/services/spot_list_service.dart';
import 'package:parkour_spot/services/saved_spot_list_service.dart';
import 'package:parkour_spot/services/spot_tracking_service.dart';
import 'package:parkour_spot/services/spot_check_in_service.dart';
import 'package:parkour_spot/services/spot_training_stats_service.dart';
import 'package:parkour_spot/services/event_interest_service.dart';
import 'package:parkour_spot/services/spot_training_plan_service.dart';
import 'package:parkour_spot/services/pwa_install_service.dart';
import 'package:parkour_spot/services/user_profile_service.dart';
import 'package:parkour_spot/services/user_locations_of_interest_service.dart';
import 'package:parkour_spot/services/user_notification_service.dart';
import 'package:parkour_spot/services/locale_preferences_service.dart';
import 'package:parkour_spot/services/web_push_subscription_service.dart';
import 'package:parkour_spot/services/firebase_resume_watchdog.dart';
import 'package:parkour_spot/widgets/inbox_notification_open_handler.dart';
import 'package:parkour_spot/router/app_router.dart';
import 'package:parkour_spot/firebase_options.dart';
import 'package:parkour_spot/config/app_config.dart';
import 'package:parkour_spot/analytics/web_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parkour_spot/utils/app_link_paths.dart';
import 'package:parkour_spot/utils/auth_emulator_origin.dart';
import 'package:parkour_spot/utils/browser_location.dart';
import 'package:parkour_spot/utils/browser_timezone_utils.dart';
import 'package:parkour_spot/utils/path_url_strategy.dart';

String? _fcmPayloadString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

bool _isParkourSpotHost(String? host) {
  if (host == null || host.isEmpty) return false;
  final h = host.toLowerCase();
  return h == 'parkour.spot' || h == 'www.parkour.spot';
}

/// Opens a parkour.spot URL that the Flutter router cannot render (see
/// [isNonAppLinkPath]).
///
/// On native the app is the verified App Links handler for the host, so
/// handing the URL to the browser would bounce straight back here; load it in
/// an in-app web view instead.
Future<void> _openNonAppLink(Uri uri) async {
  try {
    await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppWebView,
    );
  } catch (e, st) {
    debugPrint('open non-app link: $e\n$st');
  }
}

/// Opens the push / deep-link URL: in-app route when same host, else external.
Future<void> _openAppLink(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (!uri.hasScheme) {
      if (url.startsWith('/')) {
        AppRouter.router.go(url);
      }
      return;
    }

    if (_isParkourSpotHost(uri.host) ||
        (kIsWeb &&
            browserHostname() != null &&
            uri.host == browserHostname())) {
      if (isNonAppLinkPath(uri.path)) {
        await _openNonAppLink(uri);
        return;
      }
      final path = uri.path.isEmpty ? '/' : uri.path;
      final q = uri.hasQuery ? '?${uri.query}' : '';
      AppRouter.router.go('$path$q');
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e, st) {
    debugPrint('open app link: $e\n$st');
  }
}

Future<void> _openFcmForegroundLink(String url) => _openAppLink(url);

void _handleFcmOpenedMessage(RemoteMessage message) {
  final openUrl = _fcmPayloadString(message.data['openUrl']);
  if (openUrl != null) {
    unawaited(_openAppLink(openUrl));
  }
}

void _setupFcmListeners() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    final title = n?.title ?? 'Notification';
    final body = n?.body;
    final openUrl = _fcmPayloadString(message.data['openUrl']);
    SnackbarService.showFcmForeground(
      title,
      body,
      onOpenLink: openUrl != null
          ? () {
              unawaited(_openFcmForegroundLink(openUrl));
            }
          : null,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmOpenedMessage);

  unawaited(
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleFcmOpenedMessage(message);
      }
    }),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs instead of hash-based routing (web only)
  configurePathUrlStrategy();

  // Validate configuration before initializing Firebase
  AppConfig.validateConfiguration();

  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  // Must run before initializeApp so a persisted emulator user survives a new
  // tab or browser restart (see preconfigureAuthEmulatorOrigin).
  if (useEmulator) {
    preconfigureAuthEmulatorOrigin(_emulatorHost(), _authEmulatorPort);
  }

  // Web: options come from dart-defines.
  // Android/iOS: [DEFAULT] is created from google-services.json /
  // GoogleService-Info.plist. Passing dart-define options that differ from the
  // native keys (e.g. emulator dummy FIREBASE_API_KEY) throws
  // [core/duplicate-app] — Firebase.apps is still empty on the Dart side until
  // initializeApp runs, so an isEmpty guard does not help.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  // App Check: lets Cloud Functions that spend Google Maps quota verify that
  // calls come from this app. Skipped against the emulators.
  // Web: reCAPTCHA Enterprise, only when RECAPTCHA_SITE_KEY is passed at build
  // time. On localhost, web/index.html switches the SDK to debug-token mode.
  // Android: Play Integrity in release builds; debug/profile builds use the
  // debug provider, whose token is printed to logcat on first run and has to
  // be registered in the Firebase console.
  const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  var webAppCheckActive = false;
  if (!useEmulator) {
    try {
      if (kIsWeb) {
        if (recaptchaSiteKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaEnterpriseProvider(recaptchaSiteKey),
          );
          webAppCheckActive = true;
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
      }
    } catch (e) {
      debugPrint('App Check activation failed: $e');
    }
  }

  // Connect to emulators if USE_EMULATOR is set
  if (useEmulator) {
    await _connectToEmulators();
  }

  _setupFcmListeners();

  // Native: event forms default to the device timezone, which has to be
  // fetched from the OS before the first form opens.
  await primeLocalTimeZone();

  runApp(const ParkourSpotApp());

  // Web: reload when Auth / App Check tokens hang after the PWA resumes.
  FirebaseResumeWatchdog.start(appCheckActive: webAppCheckActive);

  // Initialize Google Analytics / Firebase Analytics
  WebAnalytics.init();
  WebAnalytics.trackEvent('app_start', {
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  });
}

const _authEmulatorPort = 9099;

/// Web / desktop / iOS simulator: localhost. Android emulator: host loopback.
String _emulatorHost() =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
    ? '10.0.2.2'
    : '127.0.0.1';

/// Connect Firebase services to local emulators
Future<void> _connectToEmulators() async {
  final host = _emulatorHost();

  // Emulator port configuration
  const firestorePort = 8082;
  const authPort = _authEmulatorPort;
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
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(host, functionsPort);

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

class ParkourSpotApp extends StatefulWidget {
  const ParkourSpotApp({super.key});

  @override
  State<ParkourSpotApp> createState() => _ParkourSpotAppState();
}

class _ParkourSpotAppState extends State<ParkourSpotApp> {
  StreamSubscription<Uri>? _appLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialDeepLink();
      _initAppLinks();
    });
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    if (kIsWeb) return;
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        _navigateFromUri(initial);
      }
      _appLinkSub = appLinks.uriLinkStream.listen(_navigateFromUri);
    } catch (e) {
      debugPrint('App Links init failed: $e');
    }
  }

  void _navigateFromUri(Uri uri) {
    if (!_isParkourSpotHost(uri.host) && uri.scheme != 'https') {
      // Relative or unexpected — still try path if present
      if (uri.path.isEmpty) return;
    }
    if (uri.hasScheme &&
        uri.scheme == 'https' &&
        !_isParkourSpotHost(uri.host)) {
      return;
    }
    if (isNonAppLinkPath(uri.path)) {
      if (uri.hasScheme) {
        unawaited(_openNonAppLink(uri));
      }
      return;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final q = uri.hasQuery ? '?${uri.query}' : '';
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        AppRouter.router.go('$path$q');
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
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
        ChangeNotifierProvider(create: (_) => AdminEventsService()),
        ChangeNotifierProvider(create: (_) => EventSyncSourceService()),
        ChangeNotifierProvider(create: (_) => AdminPushSubscriptionsService()),
        ChangeNotifierProvider(create: (_) => SpotService()),
        ChangeNotifierProvider(create: (_) => EventMapService()),
        ChangeNotifierProvider(create: (_) => CommunityActivityService()),
        ChangeNotifierProvider(create: (_) => SyncSourceService()),
        ChangeNotifierProvider(create: (_) => ApiClientService()),
        ChangeNotifierProvider(
          create: (_) => SearchStateService()..loadFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => GeocodingService()),
        ChangeNotifierProvider(create: (_) => JumpflixService()),
        Provider(create: (_) => SpotReportService()),
        Provider(create: (_) => EventReportService()),
        ChangeNotifierProxyProvider<AuthService, SpotListService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return SpotListService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? SpotListService(authService);
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
        Provider(create: (_) => SpotTrainingStatsService()),
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
        ChangeNotifierProxyProvider<AuthService, EventInterestService>(
          create: (context) {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            return EventInterestService(authService);
          },
          update: (context, authService, previous) {
            return previous ?? EventInterestService(authService);
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
        child: InboxNotificationOpenHandler(
          child: Consumer<LocalePreferencesService>(
            builder: (context, localePrefs, _) {
              return MaterialApp.router(
                onGenerateTitle: (_) => WebMetaUtils.defaultTitle,
                // material_ui's delegates also cover Widgets and Cupertino.
                // AppLocalizations.localizationsDelegates (generated) still
                // points at the legacy flutter_localizations classes.
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
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
                // photo_view, google_maps_flutter, webview_flutter and
                // google_sign_in still build on package:flutter/material.dart.
                // The bridge gives those legacy widgets our theme and
                // localizations. Remove once they depend on material_ui.
                builder: (context, child) =>
                    // ignore: deprecated_member_use
                    MaterialUiCompatibilityBridge(child: child!),
              );
            },
          ),
        ),
      ),
    );
  }

  void _checkInitialDeepLink() {
    if (!kIsWeb) return;
    try {
      final browserUrl = browserHref();
      if (browserUrl == null) return;
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

/// Ensures [WebPushSubscriptionService] is built after the first frame on
/// platforms that support push (web + Android).
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
    final supported = kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    if (supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Provider.of<WebPushSubscriptionService>(context, listen: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
