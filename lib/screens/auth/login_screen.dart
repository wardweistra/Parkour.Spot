import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _intendedDestination;
  bool _hasCapturedDestination = false;
  bool _hasRedirected = false;

  void _captureIntendedDestination() {
    debugPrint('LoginScreen: _captureIntendedDestination called');
    
    // Try to get the intended destination from the router state
    try {
      debugPrint('LoginScreen: Attempting to get router state...');
      final routerState = GoRouterState.of(context);
      debugPrint('LoginScreen: Successfully got router state');
      debugPrint('LoginScreen: Router state URI: ${routerState.uri}');
      debugPrint('LoginScreen: Router state path: ${routerState.uri.path}');
      debugPrint('LoginScreen: Router state query parameters: ${routerState.uri.queryParameters}');
      
      // Check if there's a redirectTo query parameter or if we came from a protected route
      final redirectTo = routerState.uri.queryParameters['redirectTo'];
      if (redirectTo != null && redirectTo.isNotEmpty) {
        // Decode the URL to handle special characters and query parameters properly
        _intendedDestination = Uri.decodeComponent(redirectTo);
        debugPrint('LoginScreen: Raw redirectTo: $redirectTo');
        debugPrint('LoginScreen: Decoded redirectTo: $_intendedDestination');
      } else {
        // Check if we came from a protected route by looking at the referrer
        // For now, we'll default to home, but this could be enhanced
        _intendedDestination = '/home';
        debugPrint('LoginScreen: No redirectTo parameter found, defaulting to home');
      }
    } catch (e) {
      // If we can't get the router state, default to home
      _intendedDestination = '/home';
      debugPrint('LoginScreen: Error getting router state: $e');
      debugPrint('LoginScreen: Stack trace: ${StackTrace.current}');
    }
    
    // Log the intended destination for debugging
    debugPrint('LoginScreen: Final intended destination: $_intendedDestination');
  }

  @override
  void initState() {
    super.initState();
    debugPrint('LoginScreen: initState called');
    
    // Listen to auth state changes to handle navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('LoginScreen: Post frame callback executing');
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.addListener(_onAuthStateChanged);
      debugPrint('LoginScreen: Auth listener added');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture intended destination after dependencies are available
    if (!_hasCapturedDestination) {
      debugPrint('LoginScreen: didChangeDependencies called, capturing destination');
      _captureIntendedDestination();
      _hasCapturedDestination = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    
    // Remove auth listener
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignore errors during disposal
    }
    
    super.dispose();
  }

  void _onAuthStateChanged() {
    debugPrint('LoginScreen: _onAuthStateChanged called');
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated && mounted) {
      debugPrint('LoginScreen: Auth state changed - user is now authenticated');
      // User is now authenticated, redirect them
      _redirectAfterAuth();
    } else {
      debugPrint('LoginScreen: Auth state changed but user not authenticated or widget not mounted');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      bool success = false;

      if (_isLogin) {
        success = await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await authService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _displayNameController.text.trim(),
        );
      }

      if (success && mounted) {
        debugPrint('LoginScreen: Authentication successful, showing success message');
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Login successful!' : 'Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        debugPrint('LoginScreen: Calling _redirectAfterAuth from form submission');
        // Navigate to intended destination or home
        _redirectAfterAuth();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _redirectAfterAuth() {
    // Prevent multiple redirects
    if (_hasRedirected) {
      debugPrint('LoginScreen: Already redirected, ignoring call');
      return;
    }
    
    // Navigate to the intended destination or home
    final destination = _intendedDestination ?? '/home';
    
    debugPrint('LoginScreen: _redirectAfterAuth called with destination: $destination');
    _hasRedirected = true;
    
    // Use a small delay to ensure the auth state change has propagated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        try {
          debugPrint('LoginScreen: Executing navigation to: $destination');
          context.go(destination);
          debugPrint('LoginScreen: Successfully navigated to: $destination');
        } catch (e) {
          debugPrint('LoginScreen: Navigation failed: $e, falling back to home');
          // If navigation fails, fall back to home
          if (mounted) {
            context.go('/home');
          }
        }
      }
    });
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo and Title
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.park,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Parkour.Spot',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isLogin ? 'Welcome back!' : 'Create your account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Display Name Field (only for sign up)
                  if (!_isLogin) ...[
                    CustomTextField(
                      controller: _displayNameController,
                      labelText: 'Display Name',
                      prefixIcon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your display name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Email Field
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  CustomButton(
                    onPressed: _isLoading ? null : _submitForm,
                    text: _isLoading 
                        ? 'Please wait...' 
                        : (_isLogin ? 'Login' : 'Sign Up'),
                    isLoading: _isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Toggle Mode Button
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isLogin 
                          ? 'Don\'t have an account? Sign Up' 
                          : 'Already have an account? Login',
                    ),
                  ),
                  
                  // Forgot Password (only for login)
                  if (_isLogin) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        // TODO: Implement forgot password
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Forgot password functionality coming soon!'),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
