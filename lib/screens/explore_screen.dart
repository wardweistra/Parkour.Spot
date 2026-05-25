import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/mobile_detection_service.dart';
import '../services/user_notification_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/pwa_install_prompt.dart';
import 'spots/search_screen.dart';
import 'add/add_hub_screen.dart';
import 'profile/profile_screen.dart';

// Countries that need "the" article prefix (e.g., "the Netherlands", not "Netherlands")
const _countriesWithArticle = {
  'NL', // Netherlands
  'PH', // Philippines
  'BS', // Bahamas
  'GM', // Gambia
  'MV', // Maldives
  'AE', // United Arab Emirates
  'US', // United States
  'GB', // United Kingdom
};

class ExploreScreen extends StatefulWidget {
  final int initialTab;
  final String? initialLocationQuery;
  final String? initialListId;
  final LatLng? initialAddSpotLocation;

  const ExploreScreen({
    super.key,
    this.initialTab = 0,
    this.initialLocationQuery,
    this.initialListId,
    this.initialAddSpotLocation,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final GlobalKey<SearchScreenState> _searchKey =
      GlobalKey<SearchScreenState>();

  /// Cached for web meta reset in [dispose] (cannot use [BuildContext] there).
  String? _cachedMetaDefaultTitle;
  String? _cachedMetaDefaultDescription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pageController = PageController(initialPage: _currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _cachedMetaDefaultTitle = l10n.exploreMetaDefaultTitle;
      _cachedMetaDefaultDescription = l10n.exploreMetaDefaultDescription;
      _updateDocumentMeta();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTab != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(widget.initialTab);
      } else if (widget.initialTab == 0) {
        // Starting on map tab - onPageChanged won't fire, so process URL params after map is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _searchKey.currentState?.onMapTabActivated();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When navigating to Explore with map-focused params (listId, locateSpotId) or
    // a different initialTab, sync the selected tab. This fixes the case where
    // the user was on Account tab, navigated away, then used "locate spot" or
    // "show list on map" - without this, GoRouter may reuse the ExploreScreen
    // instance and it would stay on the previously selected Account tab.
    if (widget.initialTab != _currentIndex) {
      setState(() => _currentIndex = widget.initialTab);
      if (_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          // When switching TO the map tab (e.g. "locate spot", "show list on map"),
          // jump straight there - no animation. Otherwise we'd briefly show the
          // previous tab (e.g. Account) before animating, which breaks the intent.
          final isMapTab = widget.initialTab == 0;
          if (isMapTab) {
            _pageController.jumpToPage(widget.initialTab);
            // onMapTabActivated is called by onPageChanged when we land on the map tab
          } else {
            _pageController.animateToPage(
              widget.initialTab,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } else if (widget.initialTab == 0) {
      // Defer to avoid setState/markNeedsBuild during build - onMapTabActivated
      // updates SearchStateService and calls setState, which cannot run mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchKey.currentState?.onMapTabActivated();
      });
    }
    if (widget.initialLocationQuery != oldWidget.initialLocationQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateDocumentMeta();
      });
    }
  }

  @override
  void dispose() {
    // Reset document title and meta description when leaving the page
    if (kIsWeb && widget.initialLocationQuery != null) {
      final title = _cachedMetaDefaultTitle ?? 'Parkour·Spot';
      final description =
          _cachedMetaDefaultDescription ??
          'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.';
      web.document.title = title;
      _updateMetaDescription(description);
      _updateMetaTitle(title);
    }
    _pageController.dispose();
    super.dispose();
  }

  void _updateDocumentMeta() {
    if (!kIsWeb || widget.initialLocationQuery == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final locationQuery = widget.initialLocationQuery!;

    // Extract country code from current URL to determine if "the" article is needed
    final countryCode = _extractCountryCodeFromUrl();

    // Check if this is a city+country format (e.g., "Amsterdam, Netherlands")
    // or just a country (e.g., "Netherlands" or "the Netherlands")
    final parts = locationQuery.split(',').map((s) => s.trim()).toList();

    String title;
    String description;

    if (parts.length >= 2) {
      // City + Country format: "City, Country"
      // For city pages, don't add "the" article (matching cloud function behavior)
      final city = parts[0];
      final country = parts
          .sublist(1)
          .join(', '); // Handle countries with commas
      title = l10n.exploreMetaTitleCityCountry(city, country);
      description = l10n.exploreMetaDescriptionCityCountry(city, country);
    } else {
      // Country only format: "Country" or "the Country"
      // For country pages, add "the" article if needed (matching cloud function behavior)
      var country = parts[0];

      // If country code is available and needs "the" article, add it
      if (countryCode != null &&
          _countriesWithArticle.contains(countryCode.toUpperCase())) {
        // Check if "the" is not already present
        if (!country.toLowerCase().startsWith('the ')) {
          country = 'the $country';
        }
      }

      title = l10n.exploreMetaTitleCountry(country);
      description = l10n.exploreMetaDescriptionCountry(country);
    }

    web.document.title = title;
    _updateMetaDescription(description);
    _updateMetaTitle(title);
  }

  /// Extract country code from the current URL path
  /// Returns null if country code cannot be determined
  String? _extractCountryCodeFromUrl() {
    if (!kIsWeb) return null;

    try {
      final uri = Uri.parse(web.window.location.href);
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      // For country-only pages: /gb -> pathSegments = ['gb']
      // For city pages: /gb/london -> pathSegments = ['gb', 'london']
      // For spot pages: /gb/london/spot-id -> pathSegments = ['gb', 'london', 'spot-id']

      if (pathSegments.isNotEmpty) {
        final firstSegment = pathSegments[0];
        // Validate it's a 2-letter country code
        if (firstSegment.length == 2 &&
            RegExp(r'^[a-zA-Z]{2}$').hasMatch(firstSegment)) {
          return firstSegment.toUpperCase();
        }
      }
    } catch (e) {
      // If URL parsing fails, return null
    }

    return null;
  }

  void _updateMetaDescription(String description) {
    if (!kIsWeb) return;

    // Find or create the meta description tag
    final metaDescription = web.document.querySelector(
      'meta[name="description"]',
    );
    if (metaDescription != null) {
      metaDescription.setAttribute('content', description);
    } else {
      // Create new meta tag if it doesn't exist
      final meta = web.document.createElement('meta') as web.HTMLMetaElement;
      meta.name = 'description';
      meta.content = description;
      web.document.head?.appendChild(meta);
    }

    // Also update Open Graph and Twitter meta tags
    final ogDescription = web.document.querySelector(
      'meta[property="og:description"]',
    );
    if (ogDescription != null) {
      ogDescription.setAttribute('content', description);
    }

    final twitterDescription = web.document.querySelector(
      'meta[name="twitter:description"]',
    );
    if (twitterDescription != null) {
      twitterDescription.setAttribute('content', description);
    }
  }

  void _updateMetaTitle(String title) {
    if (!kIsWeb) return;

    // Update Open Graph and Twitter title tags
    final ogTitle = web.document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      ogTitle.setAttribute('content', title);
    }

    final twitterTitle = web.document.querySelector(
      'meta[name="twitter:title"]',
    );
    if (twitterTitle != null) {
      twitterTitle.setAttribute('content', title);
    }
  }

  void _onTabTapped(int index) {
    // If re-tapping Explore while already on Explore, toggle bottom sheet
    if (index == 0 && _currentIndex == 0) {
      final searchState = _searchKey.currentState;
      if (searchState != null) {
        // If a map detail card is open, close it (don't touch bottom sheet)
        if (searchState.isSpotDetailOpen) {
          searchState.closeSpotDetail();
          return;
        }
        if (searchState.isEventDetailOpen) {
          searchState.closeEventDetail();
          return;
        }
        // Otherwise, toggle bottom sheet: if open, close it; if closed, open it
        if (searchState.isBottomSheetOpen) {
          searchState.collapseBottomSheetIfOpen();
        } else {
          searchState.openBottomSheetIfClosed();
        }
      }
      return;
    }
    // Profile tab (index 2) is now accessible without authentication
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Update URL to reflect current tab (but don't navigate away)
    _updateUrlForTab(index);
  }

  void _updateUrlForTab(int index) {
    // Use context.go to keep GoRouter in sync when switching tabs. This is
    // critical for the back stack: when the user navigates from Account tab to
    // Moderator/Admin tools and presses back, we need GoRouter to know we were
    // at /explore?tab=profile so it returns to Account tab, not Explore tab.
    // (Previously we used pushState which updated the URL but never notified
    // GoRouter, causing back to jump to Explore tab.)
    String newPath;
    switch (index) {
      case 0:
        // Preserve map-focused query params when switching to map tab - wiping
        // them would cause SearchScreen to lose the intent before onMapTabActivated runs.
        final uri = GoRouterState.of(context).uri;
        final listId = uri.queryParameters['listId'];
        final locateSpotId = uri.queryParameters['locateSpotId'];
        final locateEventId = uri.queryParameters['locateEventId'];
        final hasMapParams =
            (listId?.isNotEmpty ?? false) ||
            (locateSpotId?.isNotEmpty ?? false) ||
            (locateEventId?.isNotEmpty ?? false);
        if (hasMapParams) {
          final params = <String, String>{};
          if (listId != null) params['listId'] = listId;
          if (locateSpotId != null) params['locateSpotId'] = locateSpotId;
          if (locateEventId != null) params['locateEventId'] = locateEventId;
          newPath =
              '/explore?${params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
        } else {
          newPath = '/explore';
        }
        break;
      case 1:
        newPath = '/explore?tab=add';
        break;
      case 2:
        newPath = '/explore?tab=profile';
        break;
      default:
        newPath = '/explore';
    }
    if (context.mounted) {
      context.go(newPath);
    }
  }

  List<Widget> _buildScreens() {
    final authService = context.watch<AuthService>();

    return [
      SearchScreen(
        key: _searchKey,
        initialLocationQuery: widget.initialLocationQuery,
        initialListId: widget.initialListId,
      ),
      // Require profile loaded before showing contribution tools.
      authService.isProfileReady
          ? const AddHubScreen()
          : authService.isAuthenticated
          ? _buildProfileLoadingScreen(authService)
          : _buildLoginPromptScreen(Icons.add),
      // Profile tab is always accessible
      const ProfileScreen(),
    ];
  }

  Widget _buildProfileLoadingScreen(AuthService authService) {
    final l10n = AppLocalizations.of(context)!;
    final error = authService.profileLoadError;
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (error != null) ...[
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    web.window.location.reload();
                  } else {
                    await authService.retryProfileLoad();
                  }
                },
                icon: const Icon(Icons.refresh),
                label: Text(
                  kIsWeb ? l10n.profileRefreshPage : l10n.profileRetry,
                ),
              ),
            ] else ...[
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.exploreLoadingProfile,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPromptScreen(IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sign In Prompt Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.exploreSignInToAddSpot,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.exploreSignInToAddSubtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: CustomButton(
                              onPressed: () {
                                context.go(
                                  '/login?redirectTo=${Uri.encodeComponent('/explore?tab=add')}',
                                );
                              },
                              text: l10n.profileSignInButton,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // OR divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                l10n.profileOrDivider,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: CustomButton(
                              onPressed: () {
                                context.go(
                                  '/login?mode=signup&redirectTo=${Uri.encodeComponent('/explore?tab=add')}',
                                );
                              },
                              text: l10n.profileCreateAccount,
                              width: double.infinity,
                              isOutlined: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Account tab icon with an unread dot when any notification is unread (Firestore stream).
  ///
  /// Uses [Badge] with a null [Badge.label] (small circle). Do not set
  /// [Badge.isLabelVisible] to false — that flag hides the entire badge and
  /// only shows the child icon.
  Widget _accountBottomNavIcon(BuildContext context, int unreadCount) {
    const icon = Icon(Icons.person);
    if (unreadCount <= 0) return icon;
    final scheme = Theme.of(context).colorScheme;
    return Badge(smallSize: 8, backgroundColor: scheme.error, child: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // On Explore tab (mobile): don't resize when keyboard opens - the bottom sheet
      // and search bar would be pushed around. Let the keyboard overlay instead.
      // On Add Spot/Account: keep default resize so text fields scroll into view.
      resizeToAvoidBottomInset:
          !(_currentIndex == 0 && MobileDetectionService.isMobileDevice),
      body: PageView(
        controller: _pageController,
        physics: _currentIndex == 0
            ? const NeverScrollableScrollPhysics() // Disable swiping on Explore tab (map gestures)
            : const PageScrollPhysics(), // Enable swiping on other tabs
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Update URL when swiping between tabs
          _updateUrlForTab(index);
          if (index == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _searchKey.currentState?.onMapTabActivated();
            });
          }
        },
        children: _buildScreens(),
      ),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PwaInstallPrompt(),
          SafeArea(
            child: StreamBuilder<int>(
              stream: Provider.of<UserNotificationService>(
                context,
                listen: false,
              ).watchUnreadCount(),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                final l10n = AppLocalizations.of(context)!;
                return BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                  selectedItemColor: Theme.of(context).colorScheme.primary,
                  unselectedItemColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.explore),
                      label: l10n.tabExplore,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.add),
                      label: l10n.tabAdd,
                    ),
                    BottomNavigationBarItem(
                      icon: _accountBottomNavIcon(context, unread),
                      label: l10n.tabAccount,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
