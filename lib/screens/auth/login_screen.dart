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
  bool _isGoogleSignInLoading = false;
  String? _intendedDestination;
  bool _hasCapturedDestination = false;
  bool _hasRedirected = false;

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  await authService.resetPassword(emailController.text.trim());
                  if (!mounted) return;
                  navigator.pop();
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent if the address exists.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send reset email: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _captureIntendedDestination() {
    // Try to get the intended destination from the router state
    try {
      final routerState = GoRouterState.of(context);
      
      // Check if there's a redirectTo query parameter or if we came from a protected route
      final redirectTo = routerState.uri.queryParameters['redirectTo'];
      if (redirectTo != null && redirectTo.isNotEmpty) {
        // Decode the URL to handle special characters and query parameters properly
        _intendedDestination = Uri.decodeComponent(redirectTo);
      } else {
        // Check if we came from a protected route by looking at the referrer
        // For now, we'll default to home, but this could be enhanced
        _intendedDestination = '/home';
      }
    } catch (e) {
      // If we can't get the router state, default to home
      _intendedDestination = '/home';
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes to handle navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.addListener(_onAuthStateChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture intended destination after dependencies are available
    if (!_hasCapturedDestination) {
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
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated && mounted) {
      // User is now authenticated, redirect them
      _redirectAfterAuth();
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
        final isVerifiedAndAuthed = Provider.of<AuthService>(context, listen: false).isAuthenticated;

        if (_isLogin) {
          if (isVerifiedAndAuthed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful!'),
                backgroundColor: Colors.green,
              ),
            );
            _redirectAfterAuth();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please verify your email to continue.'),
                action: SnackBarAction(
                  label: 'Resend',
                  onPressed: () async {
                    try {
                      await Provider.of<AuthService>(context, listen: false).sendEmailVerification();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email sent')),
                        );
                      }
                    } catch (_) {}
                  },
                ),
              ),
            );
          }
        } else {
          // Signup flow
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created! Verification email sent to ${_emailController.text.trim()}. Please verify to continue.'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
      return;
    }
    
    // Navigate to the intended destination or home
    final destination = _intendedDestination ?? '/home';
    
    _hasRedirected = true;
    
    // Use a small delay to ensure the auth state change has propagated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        try {
          context.go(destination);
        } catch (e) {
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleSignInLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.signInWithGoogle();

      if (success && mounted) {
        final isAuthenticated = Provider.of<AuthService>(context, listen: false).isAuthenticated;
        
        if (isAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in with Google successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _redirectAfterAuth();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In failed. Please try again.'),
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
          _isGoogleSignInLoading = false;
        });
      }
    }
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
                  
                  // Google Sign-In Button
                  OutlinedButton.icon(
                    onPressed: (_isLoading || _isGoogleSignInLoading) ? null : _signInWithGoogle,
                    icon: _isGoogleSignInLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata, size: 24),
                    label: Text(
                      _isGoogleSignInLoading ? 'Signing in...' : 'Continue with Google',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Divider with "OR" text
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
                  
                  const SizedBox(height: 24),
                  
                  // Display Name Field (only for sign up)
                  if (!_isLogin) ...[
                    CustomTextField(
                      controller: _displayNameController,
                      labelText: 'Display Name',
                      prefixIcon: Icons.person,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
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
                    autofillHints: const [AutofillHints.email],
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
                    autofillHints: _isLogin 
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
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
                    onPressed: (_isLoading || _isGoogleSignInLoading) ? null : _submitForm,
                    text: _isLoading 
                        ? 'Please wait...' 
                        : (_isLogin ? 'Login' : 'Sign Up'),
                    isLoading: _isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Toggle Mode Button
                  TextButton(
                    onPressed: (_isLoading || _isGoogleSignInLoading) ? null : _toggleMode,
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
                      onPressed: (_isLoading || _isGoogleSignInLoading) ? null : () {
                        _showForgotPasswordDialog();
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
