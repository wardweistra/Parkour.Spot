import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/feature_access_service.dart';
import '../../services/pwa_install_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/profile_picture_service.dart';
import '../../models/spot_list.dart';
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

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _lottieController;
  bool _hasAnimatedOnLoad = false;
  bool _isUploadingProfilePicture = false;
  final ProfilePictureService _profilePictureService = ProfilePictureService();

  @override
  void initState() {
    super.initState();
    // Initialize with a default duration, will be updated when Lottie loads
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _handleLottieTap() {
    if (_lottieController.isAnimating) {
      // Restart animation if already playing
      _lottieController.reset();
      _lottieController.forward();
    } else {
      // Reset and start animation (handles both initial state and completed state)
      _lottieController.reset();
      _lottieController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 0,
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        'Sign in to manage your spots and rate locations.',
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
                              context.go('/login?redirectTo=${Uri.encodeComponent('/explore?tab=profile')}');
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
                              context.go('/login?mode=signup&redirectTo=${Uri.encodeComponent('/explore?tab=profile')}');
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
              
              const SizedBox(height: 16),
              
              // App Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildAboutSection(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, AuthService authService) {
    final user = authService.userProfile;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Profile Picture with edit functionality
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _isUploadingProfilePicture ? null : _showProfilePictureOptions,
                            child: CircleAvatar(
                              key: ValueKey(user?.photoURL ?? 'no-photo'), // Force rebuild when photoURL changes
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                  ? NetworkImage(_getCacheBustedImageUrl(user.photoURL!))
                                  : null,
                              child: _isUploadingProfilePicture
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : (user?.photoURL == null || user!.photoURL!.isEmpty)
                                      ? Text(
                                          user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                            ),
                          ),
                          if (!_isUploadingProfilePicture)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
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

              // Install App Banner (for mobile users not on PWA)
              if (_shouldShowInstallBanner()) ...[
                _buildInstallBanner(context),
                const SizedBox(height: 16),
              ],

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

              // Spot Lists Section
              Consumer<SpotListService>(
                builder: (context, spotListService, child) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final featureAccessService = FeatureAccessService(authService);
                  
                  if (!featureAccessService.hasFeatureAccess('spotLists')) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Spot Lists',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Create New List',
                                    onPressed: () => _showCreateListDialog(context, spotListService),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<List<SpotList>>(
                                future: spotListService.getUserSpotLists(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Error loading lists: ${snapshot.error}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    );
                                  }

                                  final lists = snapshot.data ?? [];

                                  if (lists.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.list_outlined,
                                            size: 48,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No lists yet',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () => _showCreateListDialog(context, spotListService),
                                            child: const Text('Create your first list'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: lists.map((list) {
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          title: Text(list.name),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (list.description != null && list.description!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    list.description!,
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '${list.spotCount} ${list.spotCount == 1 ? 'spot' : 'spots'}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                tooltip: 'Edit',
                                                onPressed: () => _showEditListDialog(context, spotListService, list),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                tooltip: 'Delete',
                                                onPressed: () => _showDeleteListDialog(context, spotListService, list),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            if (list.id != null) {
                                              context.go('/list/${list.id}?from=profile');
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              
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
        ),
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
    const beforeLink = 'Started by ';
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
        const SizedBox(height: 16),
        SelectableText.rich(
          TextSpan(
            style: textStyle,
            children: [
              const TextSpan(text: 'Major contributions by '),
              TextSpan(
                text: 'Daphne Fontijn',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse('https://www.instagram.com/daphnefontijn/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              const TextSpan(text: ' (art), '),
              TextSpan(
                text: 'Tim Haerkens',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse('https://www.instagram.com/tim.haerkens/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'Marily Bronkhorst',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse('https://www.instagram.com/marilybronk/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              const TextSpan(text: ' and many others.'),
            ],
          ),
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
        
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SizedBox(
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 2773 / 646, // From SVG viewBox
                        child: GestureDetector(
                          onTap: _handleLottieTap,
                          child: Lottie.asset(
                            Theme.of(context).brightness == Brightness.dark
                                ? 'assets/images/lottie-dark.json'
                                : 'assets/images/lottie.json',
                            controller: _lottieController,
                            fit: BoxFit.contain,
                            repeat: false,
                            animate: false,
                            onLoaded: (composition) {
                              // Update controller duration based on loaded composition
                              _lottieController.duration = composition.duration;
                              // Animate once on first load
                              if (!_hasAnimatedOnLoad) {
                                _hasAnimatedOnLoad = true;
                                _lottieController.forward();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isWideScreen ? 32 : 16),
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
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 350),
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
            ),
          ),
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

  void _showCreateListDialog(BuildContext context, SpotListService spotListService) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., My Favorite Spots',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add a description for this list',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('List name cannot be empty')),
                );
                return;
              }

              final listId = await spotListService.createSpotList(
                nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                if (listId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List created successfully')),
                  );
                } else if (spotListService.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(spotListService.error!)),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditListDialog(BuildContext context, SpotListService spotListService, SpotList list) {
    final nameController = TextEditingController(text: list.name);
    final descriptionController = TextEditingController(text: list.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'List Name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('List name cannot be empty')),
                );
                return;
              }

              final success = await spotListService.updateSpotList(
                list.id!,
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List updated successfully')),
                  );
                } else if (spotListService.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(spotListService.error!)),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteListDialog(BuildContext context, SpotListService spotListService, SpotList list) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = await spotListService.deleteSpotList(list.id!);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('List deleted successfully')),
                  );
                } else if (spotListService.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(spotListService.error!)),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Check if install banner should be shown
  /// Always shown on mobile when not running as PWA (regardless of engagement)
  bool _shouldShowInstallBanner() {
    if (!MobileDetectionService.isMobileDevice) return false;
    if (MobileDetectionService.isRunningAsPWA) return false;
    
    return true;
  }

  /// Build the install app banner
  Widget _buildInstallBanner(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _showInstallInstructions(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.get_app,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Install the Parkour·Spot app',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get the full app experience',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show install instructions dialog
  void _showInstallInstructions(BuildContext context) {
    final pwaService = PwaInstallService();
    final instructions = MobileDetectionService.isIOS
        ? pwaService.getIOSInstallInstructions()
        : pwaService.getAndroidInstallInstructions();
    
    final platformName = MobileDetectionService.isIOS ? 'iPhone' : 'Android device';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.get_app, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(instructions['title']!)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To install Parkour·Spot on your $platformName:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInstallInstructionStep(dialogContext, '1', instructions['step1']!),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '2', instructions['step2']!),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '3', instructions['step3']!),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '4', instructions['step4']!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Add cache-busting query parameter to image URL
  /// For Firebase Storage URLs (which we control), use timestamp to bust cache
  /// For other URLs, use URL hash to allow caching but bust when URL changes
  String _getCacheBustedImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // For Firebase Storage URLs, use timestamp to ensure fresh image
      // This is important because the same URL can have different content after upload
      final isFirebaseStorage = url.contains('firebasestorage.googleapis.com') ||
          url.contains('storage.googleapis.com');
      
      final version = isFirebaseStorage
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : url.hashCode.toString();
      
      final cacheBustedUri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'v': version,
        },
      );
      return cacheBustedUri.toString();
    } catch (e) {
      // If URL parsing fails, return original URL with query param appended
      final separator = url.contains('?') ? '&' : '?';
      final isFirebaseStorage = url.contains('firebasestorage.googleapis.com') ||
          url.contains('storage.googleapis.com');
      final version = isFirebaseStorage
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : url.hashCode.toString();
      return '$url${separator}v=$version';
    }
  }

  Widget _buildInstallInstructionStep(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Show dialog with options to change profile picture
  void _showProfilePictureOptions() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userProfile;
    final hasPhoto = user?.photoURL != null && user!.photoURL!.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(dialogContext);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(dialogContext);
                _takePhoto();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Remove Picture',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _removeProfilePicture();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        await _uploadProfilePicture(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Take photo with camera
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        await _uploadProfilePicture(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upload profile picture from XFile
  Future<void> _uploadProfilePicture(XFile pickedFile) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!mounted) return;

    setState(() {
      _isUploadingProfilePicture = true;
    });

    // Show progress dialog with state management
    double uploadProgress = 0.0;
    String statusMessage = 'Processing image...';
    
    BuildContext? dialogContext;
    StateSetter? dialogSetState;
    final dialogReady = Completer<void>();

    // Helper function to update progress
    void updateProgress(double progress, String message) {
      uploadProgress = progress;
      statusMessage = message;
      if (mounted && dialogSetState != null) {
        dialogSetState!(() {});
      }
    }

    // Show dialog (don't await, we'll wait for the completer instead)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            // Set dialogSetState and complete the completer when dialog is built
            if (dialogSetState == null) {
              dialogSetState = setState;
              if (!dialogReady.isCompleted) {
                dialogReady.complete();
              }
            }
            return WillPopScope(
              onWillPop: () async => false, // Prevent dismissing during upload
              child: AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: uploadProgress,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(uploadProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Wait for dialog to be built before starting upload
    await dialogReady.future;

    try {
      String photoURL;

      if (kIsWeb) {
        // Web: read as bytes
        updateProgress(0.1, 'Reading image...');
        final bytes = await pickedFile.readAsBytes();
        
        // Upload with progress updates
        photoURL = await _profilePictureService.uploadProfilePictureBytes(
          bytes,
          onProgress: (progress) {
            String message;
            if (progress < 0.3) {
              message = 'Processing image...';
            } else if (progress < 0.9) {
              message = 'Uploading...';
            } else {
              message = 'Finishing...';
            }
            updateProgress(progress, message);
          },
        );
      } else {
        // Mobile: use File
        updateProgress(0.1, 'Reading image...');
        final file = File(pickedFile.path);
        
        // Upload with progress updates
        photoURL = await _profilePictureService.uploadProfilePicture(
          file,
          onProgress: (progress) {
            String message;
            if (progress < 0.3) {
              message = 'Processing image...';
            } else if (progress < 0.9) {
              message = 'Uploading...';
            } else {
              message = 'Finishing...';
            }
            updateProgress(progress, message);
          },
        );
      }

      // Update profile
      updateProgress(0.95, 'Updating profile...');
      final success = await authService.updateProfile(
        photoURL: photoURL,
        deleteOldPhoto: true,
      );

      // Close progress dialog
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile picture'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close progress dialog
      if (mounted && dialogContext != null) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfilePicture = false;
        });
      }
    }
  }

  /// Remove profile picture
  Future<void> _removeProfilePicture() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userProfile;

    if (user?.photoURL == null || user!.photoURL!.isEmpty) {
      return;
    }

    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) {
      return;
    }

    setState(() {
      _isUploadingProfilePicture = true;
    });

    try {
      // Delete from Storage first
      await _profilePictureService.deleteProfilePicture();

      // Update profile to remove photoURL
      final success = await authService.updateProfile(
        removePhoto: true,
        deleteOldPhoto: false,
      );

      // Wait a frame to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        if (success) {
          // Force a rebuild of the profile content
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove profile picture'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfilePicture = false;
        });
      }
    }
  }
}
