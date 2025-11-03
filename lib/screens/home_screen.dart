import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import 'spots/search_screen.dart';
import 'spots/add_spot_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final GlobalKey<SearchScreenState> _searchKey = GlobalKey<SearchScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pageController = PageController(initialPage: _currentIndex);
    
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
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // If re-tapping Home while already on Home, collapse the bottom sheet
    if (index == 0 && _currentIndex == 0) {
      _searchKey.currentState?.collapseBottomSheetIfOpen();
      _searchKey.currentState?.closeSpotDetailIfOpen();
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
    // Update URL without navigating away from the home screen
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/home?tab=add');
        break;
      case 2:
        context.go('/home?tab=profile');
        break;
    }
  }

  List<Widget> _buildScreens() {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return [
      SearchScreen(key: _searchKey),
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
        title: Text(title),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/login?redirectTo=${Uri.encodeComponent('/home?tab=profile')}');
                },
                icon: const Icon(Icons.login),
                label: const Text('Login to Continue'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Go back to spots list
                  setState(() {
                    _currentIndex = 0;
                  });
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  context.go('/home');
                },
                child: const Text('Continue Browsing'),
              ),
            ],
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
            ? const NeverScrollableScrollPhysics() // Disable swiping on Home tab (map gestures)
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

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
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
    );
  }
}
