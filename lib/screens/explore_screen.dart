import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/pwa_install_prompt.dart';
import 'spots/search_screen.dart';
import 'spots/add_spot_screen.dart';
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
  
  const ExploreScreen({super.key, this.initialTab = 0, this.initialLocationQuery, this.initialListId});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final GlobalKey<SearchScreenState> _searchKey = GlobalKey<SearchScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Update document title and meta description for country/city pages
    _updateDocumentMeta();
    
    // Initialize page controller position if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If we have an initial tab that's not 0, ensure the page controller is at the right position
      if (widget.initialTab != 0 && _pageController.hasClients) {
        _pageController.jumpToPage(widget.initialTab);
      }
    });
  }

  @override
  void dispose() {
    // Reset document title and meta description when leaving the page
    if (kIsWeb && widget.initialLocationQuery != null) {
      const defaultTitle = 'Parkour·Spot';
      const defaultDescription = 'Discover and share parkour spots around the world';
      web.document.title = defaultTitle;
      _updateMetaDescription(defaultDescription);
      _updateMetaTitle(defaultTitle);
    }
    _pageController.dispose();
    super.dispose();
  }

  void _updateDocumentMeta() {
    if (!kIsWeb || widget.initialLocationQuery == null) {
      return;
    }

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
      final country = parts.sublist(1).join(', '); // Handle countries with commas
      title = 'Best parkour spots in $city, $country';
      description = 'Discover the best parkour spots in $city, $country. Find training locations, share your favorite spots, and connect with the parkour community.';
    } else {
      // Country only format: "Country" or "the Country"
      // For country pages, add "the" article if needed (matching cloud function behavior)
      var country = parts[0];
      
      // If country code is available and needs "the" article, add it
      if (countryCode != null && _countriesWithArticle.contains(countryCode.toUpperCase())) {
        // Check if "the" is not already present
        if (!country.toLowerCase().startsWith('the ')) {
          country = 'the $country';
        }
      }
      
      title = 'Best parkour spots in $country';
      description = 'Discover the best parkour spots in $country. Find training locations, share your favorite spots, and connect with the parkour community.';
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
        if (firstSegment.length == 2 && RegExp(r'^[a-zA-Z]{2}$').hasMatch(firstSegment)) {
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
    final metaDescription = web.document.querySelector('meta[name="description"]');
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
    final ogDescription = web.document.querySelector('meta[property="og:description"]');
    if (ogDescription != null) {
      ogDescription.setAttribute('content', description);
    }
    
    final twitterDescription = web.document.querySelector('meta[name="twitter:description"]');
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
    
    final twitterTitle = web.document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null) {
      twitterTitle.setAttribute('content', title);
    }
  }

  void _onTabTapped(int index) {
    // If re-tapping Explore while already on Explore, toggle bottom sheet
    if (index == 0 && _currentIndex == 0) {
      final searchState = _searchKey.currentState;
      if (searchState != null) {
        // If Spot Detail Card is open, close it (don't touch bottom sheet)
        if (searchState.isSpotDetailOpen) {
          searchState.closeSpotDetail();
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
    // Update URL without navigating away from the explore screen
    // Use pushState to update URL without triggering GoRouter navigation
    // This prevents the screen from being rebuilt and avoids double-loading
    if (kIsWeb) {
      String newPath;
      switch (index) {
        case 0:
          newPath = '/explore';
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
      // Use pushState to update URL without triggering router rebuild
      web.window.history.pushState(null, '', newPath);
    }
  }

  List<Widget> _buildScreens() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return [
      SearchScreen(
        key: _searchKey,
        initialLocationQuery: widget.initialLocationQuery,
        initialListId: widget.initialListId,
      ),
      // Show login prompt for unauthenticated users trying to add spots
      authService.isAuthenticated 
          ? const AddSpotScreen() 
          : _buildLoginPromptScreen(
              'Add New Spot',
              'Share your favorite parkour spots with the community',
              Icons.add_location,
            ),
      // Profile tab is always accessible
      const ProfileScreen(),
    ];
  }

  Widget _buildLoginPromptScreen(String title, String description, IconData icon) {
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
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sign in to add a spot',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: CustomButton(
                              onPressed: () {
                                context.go('/login?redirectTo=${Uri.encodeComponent('/explore?tab=add')}');
                              },
                              text: 'Sign In',
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
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                                context.go('/login?mode=signup&redirectTo=${Uri.encodeComponent('/explore?tab=add')}');
                              },
                              text: 'Create an Account',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        },
        children: _buildScreens(),
      ),

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PwaInstallPrompt(),
          SafeArea(
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 8,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_location),
                  label: 'Add Spot',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

