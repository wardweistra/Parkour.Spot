import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // Array of inspirational messages
  static const List<String> _messages = [
    'For those who start together and finish together',
    'For those who leave their spot better than they found it',
    'For those who are strong to be useful',
  ];
  
  late String _selectedMessage;

  @override
  void initState() {
    super.initState();
    
    // Select a random message
    final random = Random();
    _selectedMessage = _messages[random.nextInt(_messages.length)];
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    
    // Check authentication status after animation
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check if we're already on a spot route
    String? currentPath;
    
    // Method 1: Check the current route state
    try {
      final routerState = GoRouterState.of(context);
      currentPath = routerState.uri.path;
    } catch (e) {
      // Could not get router state
    }
    
    // Method 2: Check if we're in a spot route by looking at the current location
    if (currentPath == null || currentPath == '/') {
      try {
        final router = GoRouter.of(context);
        final location = router.routerDelegate.currentConfiguration.uri.path;
        if (_isSpotUrl(location)) {
          currentPath = location;
        }
      } catch (e) {
        // Could not get location
      }
    }
    
    // Method 3: Check the browser URL directly (web-specific)
    if (currentPath == null || currentPath == '/') {
      try {
        // This is a web-specific approach to get the current URL
        final uri = Uri.parse(web.window.location.href);
        if (_isSpotUrl(uri.path)) {
          currentPath = uri.path;
        }
      } catch (e) {
        // Could not get browser URL
      }
    }
    
    // If we have a spot URL, navigate directly to it (router will handle auth)
    if (currentPath != null && _isSpotUrl(currentPath)) {
      context.go(currentPath);
      return;
    }
    
    // Allow both authenticated and unauthenticated users to access public features
    // Navigate to home for all users - authentication will be handled per-feature
    context.go('/home');
  }
  
  /// Check if the given path is a spot URL
  /// Supports format: /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
  /// where xx is a 2-letter country code
  bool _isSpotUrl(String path) {
    // Format: /nl/amsterdam/&lt;spot-id&gt; or any /&lt;xx&gt;/&lt;anything&gt;/&lt;spot-id&gt;
    if (path.split('/').where((segment) => segment.isNotEmpty).length == 3) {
      final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
      final countryCode = segments[0];
      return countryCode.length == 2 && RegExp(r'^[a-zA-Z]{2}$').hasMatch(countryCode);
    }
    
    return false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon/Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.park,
                        size: 80,
                        color: Colors.blue,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // App Name
                    Text(
                      'Parkour.Spot',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Header
                    Text(
                      'Parkour.Spot',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Random inspirational message
                    Text(
                      _selectedMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Loading indicator
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
