import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    
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
    
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Check if we have a deep link to handle - use multiple methods
      String? currentPath;
      
      // Method 1: Check the current router location directly
      try {
        final router = GoRouter.of(context);
        currentPath = router.routerDelegate.currentConfiguration.uri.path;
      } catch (e) {
        // Router not available yet
      }
      
      // Method 2: If router failed, try GoRouterState
      if (currentPath == null || currentPath == '/') {
        try {
          currentPath = GoRouterState.of(context).uri.path;
        } catch (e) {
          // GoRouterState not available yet
        }
      }
      
      // Method 3: Check if we're in a spot route by looking at the current location
      if (currentPath == null || currentPath == '/') {
        try {
          final router = GoRouter.of(context);
          final location = router.routerDelegate.currentConfiguration.uri.path;
          if (location.startsWith('/spot/') || location.startsWith('/s/')) {
            currentPath = location;
          }
        } catch (e) {
          // Could not get location
        }
      }
      
      // Method 4: Check the browser URL directly (web-specific)
      if (currentPath == null || currentPath == '/') {
        try {
          // This is a web-specific approach to get the current URL
          final uri = Uri.parse(web.window.location.href);
          if (uri.path.startsWith('/spot/') || uri.path.startsWith('/s/')) {
            currentPath = uri.path;
          }
        } catch (e) {
          // Could not get browser URL
        }
      }
      
      // If we have a spot URL, navigate directly to it (router will handle auth)
      if (currentPath != null && 
          (currentPath.startsWith('/spot/') || currentPath.startsWith('/s/'))) {
        context.go(currentPath);
        return;
      }
      
      // Otherwise, follow normal auth flow
      if (authService.isAuthenticated) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    }
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
                      'ParkourSpot',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Tagline
                    Text(
                      'Discover & Share Parkour Spots',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
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
