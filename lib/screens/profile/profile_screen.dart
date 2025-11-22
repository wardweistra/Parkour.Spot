import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/instagram_button.dart';
import '../../widgets/github_button.dart';
import '../../widgets/report_issue_button.dart';
import '../../widgets/email_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isExpanded = false;

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
              child: _buildAboutSection(context),
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
                      context.go('/login?redirectTo=${Uri.encodeComponent('/explore?tab=profile')}');
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

          if (authService.isModerator || authService.isAdmin) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moderator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionTile(
                      context,
                      Icons.shield,
                      'Moderator Tools',
                      'Review and resolve incoming spot reports',
                      () {
                        context.go('/moderator');
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],

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
              child: _buildAboutSection(context),
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
                  context.go('/explore?tab=profile');
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

  Widget _buildExpandedText(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
    
    final linkStyle = textStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    
    // Split the text at "Ward Weistra"
    const beforeLink = 'Built by ';
    const linkText = 'Ward Weistra';
    const afterLink = ' from the Utrecht parkour community, the app brings together local knowledge from existing city and regional maps—whether they lived on Facebook, Instagram, websites, or retired apps—so great spot data doesn\'t get lost.';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(
            style: textStyle,
            children: [
              TextSpan(text: beforeLink),
              TextSpan(
                text: linkText,
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse('https://www.instagram.com/wardweistra/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              TextSpan(text: afterLink),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          'This is your map. Add new spots, rate existing ones, and enrich listings with details. The more we contribute, the stronger the community\'s shared knowledge becomes.',
          style: textStyle,
        ),
        const SizedBox(height: 16),
        SelectableText(
          'Our principles:',
          style: textStyle?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                '• Transparency: you can browse the app without an account, and each spot shows which external sources contributed to it.',
                style: textStyle,
              ),
              const SizedBox(height: 8),
              SelectableText(
                '• Portability: we\'re building export tools so spot data can be used beyond the app.',
                style: textStyle,
              ),
              const SizedBox(height: 8),
              SelectableText(
                '• Open source: the app is community-owned, not dependent on one person.',
                style: textStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          'Enjoy discovering and sharing spots with Parkour.spot. Questions or ideas? Tap the contact button—we\'d love to hear from you.',
          style: textStyle,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 2773 / 646, // From SVG viewBox
                    child: SvgPicture.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/images/logo-with-text-dark.svg'
                          : 'assets/images/logo-with-text.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            isWideScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.',
                                  style: textStyle,
                                ),
                                if (!_isExpanded) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isExpanded = true;
                                      });
                                    },
                                    child: Text(
                                      'Read more',
                                      style: textStyle?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                                const SizedBox(height: 16),
                                EmailButton(
                                  email: 'parkour.spot@wardweistra.nl',
                                  label: 'Contact us',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 16),
                        _buildExpandedText(context),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.',
                        style: textStyle,
                      ),
                      if (!_isExpanded) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded = true;
                            });
                          },
                          child: Text(
                            'Read more',
                            style: textStyle?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                      if (_isExpanded) ...[
                        const SizedBox(height: 16),
                        _buildExpandedText(context),
                      ],
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
                      const SizedBox(height: 16),
                      EmailButton(
                        email: 'parkour.spot@wardweistra.nl',
                        label: 'Contact us',
                      ),
                    ],
                  ),
          ],
        );
      },
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
