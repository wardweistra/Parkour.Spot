import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/instagram_button.dart';
import '../../widgets/github_button.dart';
import '../../widgets/report_issue_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (!authService.isAuthenticated) {
            return _buildAppInfo(context);
          }

          return _buildProfileContent(context, authService);
        },
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 600;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      isWideScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Parkour.Spot is an open source app for finding and sharing spots for parkour and freerunning. Discover new locations, share your favorite spots, and connect with the parkour community.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    children: [
                                      InstagramButton(
                                        handle: 'parkourdotspot',
                                        label: '@parkourdotspot',
                                      ),
                                      const SizedBox(height: 16),
                                      GitHubButton(
                                        url: 'https://github.com/wardweistra/Parkour.Spot/',
                                        label: 'View source code',
                                      ),
                                      const SizedBox(height: 16),
                                      ReportIssueButton(
                                        url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parkour.Spot is an open source app for finding and sharing spots for parkour and freerunning. Discover new locations, share your favorite spots, and connect with the parkour community.',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InstagramButton(
                                  handle: 'parkourdotspot',
                                  label: '@parkourdotspot',
                                ),
                                const SizedBox(height: 16),
                                GitHubButton(
                                  url: 'https://github.com/wardweistra/Parkour.Spot/',
                                  label: 'View source code',
                                ),
                                const SizedBox(height: 16),
                                ReportIssueButton(
                                  url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                                ),
                              ],
                            ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sign In Prompt
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to access your profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your spots, rate locations, and save favorites.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    onPressed: () {
                      context.go('/login?redirectTo=${Uri.encodeComponent('/home?tab=profile')}');
                    },
                    text: 'Sign In',
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, AuthService authService) {
    final user = authService.userProfile;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // User Name
                  Text(
                    user?.displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // User Email
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          if (authService.isAdmin) ...[
            // Administrator Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      Icons.admin_panel_settings,
                      'Admin Tools',
                      'Manage sources and administrative tasks',
                      () {
                        context.go('/admin');
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
          
          // App Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 600;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      isWideScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Parkour.Spot is an open source app for finding and sharing spots for parkour and freerunning. Discover new locations, share your favorite spots, and connect with the parkour community.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    children: [
                                      InstagramButton(
                                        handle: 'parkourdotspot',
                                        label: '@parkourdotspot',
                                      ),
                                      const SizedBox(height: 16),
                                      GitHubButton(
                                        url: 'https://github.com/wardweistra/Parkour.Spot/',
                                        label: 'View source code',
                                      ),
                                      const SizedBox(height: 16),
                                      ReportIssueButton(
                                        url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parkour.Spot is an open source app for finding and sharing spots for parkour and freerunning. Discover new locations, share your favorite spots, and connect with the parkour community.',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InstagramButton(
                                  handle: 'parkourdotspot',
                                  label: '@parkourdotspot',
                                ),
                                const SizedBox(height: 16),
                                GitHubButton(
                                  url: 'https://github.com/wardweistra/Parkour.Spot/',
                                  label: 'View source code',
                                ),
                                const SizedBox(height: 16),
                                ReportIssueButton(
                                  url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                                ),
                              ],
                            ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sign Out Button
          CustomButton(
            onPressed: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              
              if (shouldSignOut == true) {
                await authService.signOut();
                if (context.mounted) {
                  context.go('/home?tab=profile');
                }
              }
            },
            text: 'Sign Out',
            icon: Icons.logout,
            backgroundColor: Theme.of(context).colorScheme.error,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
