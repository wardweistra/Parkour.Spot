import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:lottie/lottie.dart';
import '../../services/auth_service.dart';
import '../../services/locale_preferences_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/instagram_button.dart';
import '../../widgets/github_button.dart';
import '../../widgets/report_issue_button.dart';
import '../../widgets/email_button.dart';
import '../../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _lottieController;
  bool _hasAnimatedOnLoad = false;

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
          if (authService.profileLoadError != null) {
            return _buildProfileLoadError(context, authService);
          }
          return _buildProfileContent(context, authService);
        },
      ),
    );
  }

  Widget _buildProfileLoadError(BuildContext context, AuthService authService) {
    final l10n = AppLocalizations.of(context)!;
    final error = authService.profileLoadError ?? l10n.profileLoadErrorDefault;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
              label: Text(kIsWeb ? l10n.profileRefreshPage : l10n.profileRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                        l10n.profileSignInTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.profileSignInSubtitle,
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
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              l10n.profileOrDivider,
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
    final l10n = AppLocalizations.of(context)!;
    final user = authService.userProfile;
    
    // Determine profile URL - use username if available, otherwise user ID
    final profileUrl = user != null && user.username != null && user.username!.isNotEmpty
        ? '/user/${user.username}'
        : user?.id != null
            ? '/user/${user!.id}'
            : null;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Compact Account Card - links to full profile
              // Uses same layout as Profile page (CircleAvatar not in ListTile) to avoid clipping
              if (profileUrl != null)
                Card(
                  child: InkWell(
                    onTap: () => context.push(profileUrl),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            key: ValueKey(user?.photoURL ?? 'no-photo'),
                            radius: 36,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            backgroundImage: user != null && user.photoURL != null && user.photoURL!.isNotEmpty
                                ? NetworkImage(_getCacheBustedImageUrl(user.photoURL!))
                                : null,
                            child: (user?.photoURL?.isEmpty ?? true)
                                ? Text(
                                    user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? l10n.profileDefaultDisplayName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.profileViewEditSubtitle,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                ),

              const SizedBox(height: 16),

              Consumer<LocalePreferencesService>(
                builder: (context, localePrefs, _) {
                  final l10n = AppLocalizations.of(context)!;
                  final scheme = Theme.of(context).colorScheme;
                  final selection =
                      localePrefs.overrideLanguageCode ?? 'system';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileSettingsTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.profileSettingsLanguageLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.profileSettingsLanguageDescription,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ButtonTheme.fromButtonThemeData(
                              data: ButtonTheme.of(context).copyWith(
                                alignedDropdown: false,
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    // Avoid a persistent grey fill after the menu closes (web focus).
                                    focusColor: Colors.transparent,
                                    hoverColor: scheme.onSurface
                                        .withValues(alpha: 0.06),
                                    splashColor: scheme.onSurface
                                        .withValues(alpha: 0.10),
                                    highlightColor: scheme.onSurface
                                        .withValues(alpha: 0.06),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selection,
                                      isExpanded: true,
                                      isDense: true,
                                      focusColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'system',
                                          child: Text(
                                            l10n.profileLanguageSystemDefault,
                                          ),
                                        ),
                                        ...LocalePreferencesService
                                            .supportedLanguageCodes()
                                            .map(
                                          (code) => DropdownMenuItem(
                                            value: code,
                                            child: Text(
                                              LocalePreferencesService
                                                  .nativeLanguageLabel(code),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        if (value == 'system') {
                                          await localePrefs.clearOverride();
                                        } else {
                                          await localePrefs.setOverride(value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                          l10n.profileModeratorSectionTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _buildActionTile(
                          context,
                          Icons.shield,
                          l10n.profileModeratorToolsTitle,
                          l10n.profileModeratorToolsSubtitle,
                          () {
                            context.push('/moderator');
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
                          l10n.profileAdminSectionTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _buildActionTile(
                          context,
                          Icons.admin_panel_settings,
                          l10n.profileAdminToolsTitle,
                          l10n.profileAdminToolsSubtitle,
                          () {
                            context.push('/admin');
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
                    builder: (dialogContext) {
                      final dlgL10n = AppLocalizations.of(dialogContext)!;
                      return AlertDialog(
                        title: Text(dlgL10n.profileSignOut),
                        content: Text(dlgL10n.profileSignOutMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: Text(dlgL10n.profileCancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(dlgL10n.profileSignOut),
                          ),
                        ],
                      );
                    },
                  );
                  
                  if (shouldSignOut == true) {
                    await authService.signOut();
                    if (context.mounted) {
                      context.go('/explore?tab=profile');
                    }
                  }
                },
                text: l10n.profileSignOut,
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

  Widget _buildExpandedText(BuildContext context, AppLocalizations l10n) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
    
    final linkStyle = textStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    
    const linkText = 'Ward Weistra';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(
            style: textStyle,
            children: [
              TextSpan(text: l10n.profileAboutStoryBeforeName),
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
              TextSpan(text: l10n.profileAboutStoryAfterName),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          l10n.profileAboutMapMission,
          style: textStyle,
        ),
        const SizedBox(height: 16),
        SelectableText(
          l10n.profileAboutPrinciplesHeader,
          style: textStyle,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                l10n.profileAboutPrincipleTransparency,
                style: textStyle,
              ),
              const SizedBox(height: 8),
              SelectableText(
                l10n.profileAboutPrinciplePortability,
                style: textStyle,
              ),
              const SizedBox(height: 8),
              SelectableText(
                l10n.profileAboutPrincipleOpenSource,
                style: textStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          l10n.profileAboutEnjoy,
          style: textStyle,
        ),
        const SizedBox(height: 16),
        SelectableText.rich(
          TextSpan(
            style: textStyle,
            children: [
              TextSpan(text: l10n.profileCreditsBy),
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
              TextSpan(text: l10n.profileCreditsDaphneArt),
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
              TextSpan(text: l10n.profileCreditsComma),
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
              TextSpan(text: l10n.profileCreditsEnd),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                                      l10n.profileAboutIntro,
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
                                          l10n.profileReadMore,
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
                                          label: l10n.profileViewSourceCode,
                                        ),
                                        const SizedBox(height: 16),
                                        ReportIssueButton(
                                          url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                                          label: l10n.profileReportIssue,
                                        ),
                                        const SizedBox(height: 16),
                                        EmailButton(
                                          email: 'parkour.spot@wardweistra.nl',
                                          label: l10n.profileContactUs,
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
                            _buildExpandedText(context, l10n),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            l10n.profileAboutIntro,
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
                                l10n.profileReadMore,
                                style: textStyle?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          if (_isExpanded) ...[
                            const SizedBox(height: 16),
                            _buildExpandedText(context, l10n),
                          ],
                          const SizedBox(height: 16),
                          InstagramButton(
                            handle: 'parkourdotspot',
                            label: '@parkourdotspot',
                          ),
                          const SizedBox(height: 16),
                          GitHubButton(
                            url: 'https://github.com/wardweistra/Parkour.Spot/',
                            label: l10n.profileViewSourceCode,
                          ),
                          const SizedBox(height: 16),
                          ReportIssueButton(
                            url: 'https://github.com/wardweistra/Parkour.Spot/issues',
                            label: l10n.profileReportIssue,
                          ),
                          const SizedBox(height: 16),
                          EmailButton(
                            email: 'parkour.spot@wardweistra.nl',
                            label: l10n.profileContactUs,
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

  /// Check if install banner should be shown
  /// Always shown on mobile when not running as PWA (regardless of engagement)
  bool _shouldShowInstallBanner() {
    if (!MobileDetectionService.isMobileDevice) return false;
    if (MobileDetectionService.isRunningAsPWA) return false;
    
    return true;
  }

  /// Build the install app banner
  Widget _buildInstallBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      l10n.profileInstallBannerTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profileInstallBannerSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    final isIos = MobileDetectionService.isIOS;
    final deviceLabel =
        isIos ? l10n.profileInstallDeviceIphone : l10n.profileInstallDeviceAndroid;
    final step1 = isIos ? l10n.profileInstallIosStep1 : l10n.profileInstallAndroidStep1;
    final step2 = isIos ? l10n.profileInstallIosStep2 : l10n.profileInstallAndroidStep2;
    final step3 = isIos ? l10n.profileInstallIosStep3 : l10n.profileInstallAndroidStep3;
    final step4 = isIos ? l10n.profileInstallIosStep4 : l10n.profileInstallAndroidStep4;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.get_app, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.profileInstallDialogTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileInstallIntro(deviceLabel),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInstallInstructionStep(dialogContext, '1', step1),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '2', step2),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '3', step3),
            const SizedBox(height: 12),
            _buildInstallInstructionStep(dialogContext, '4', step4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.profileInstallGotIt),
          ),
        ],
      ),
    );
  }

  /// Add cache-busting query parameter to image URL
  String _getCacheBustedImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
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
}
