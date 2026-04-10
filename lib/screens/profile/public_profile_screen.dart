import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_picture_service.dart';
import '../../services/url_service.dart';
import '../../services/web_share_service.dart';
import '../../models/user.dart' as app_user;
import '../../models/spot_list.dart';
import '../../services/spot_list_service.dart';
import '../../services/saved_spot_list_service.dart';
import '../../services/feature_access_service.dart';
import '../../widgets/instagram_button.dart';
import '../../utils/web_meta_utils.dart';
import '../../widgets/page_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/spot_list_localization.dart';
import 'package:flutter/services.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userIdOrUsername;

  const PublicProfileScreen({super.key, required this.userIdOrUsername});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<app_user.User?>? _profileFuture;
  String?
  _lastUserIdOrUsername; // Track the last userIdOrUsername used to create the future
  bool _isUploadingProfilePicture = false;
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  final GlobalKey _savedSpotListsSectionKey = GlobalKey();
  bool _didScrollToSavedSpotListsSection = false;

  String _spotCountLabel(int count) => _l10n.exploreSpotCountShort(count);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset future if userIdOrUsername has changed
    if (_profileFuture == null ||
        _lastUserIdOrUsername != widget.userIdOrUsername) {
      _loadProfile();
    }
    _scheduleScrollToSavedSpotListsSection();
  }

  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If userIdOrUsername changed, reload the profile
    if (oldWidget.userIdOrUsername != widget.userIdOrUsername) {
      _loadProfile();
      _didScrollToSavedSpotListsSection = false;
    }
  }

  void _scheduleScrollToSavedSpotListsSection() {
    final section = GoRouterState.of(context).uri.queryParameters['section'];
    if (section != 'saved-lists') {
      _didScrollToSavedSpotListsSection = false;
      return;
    }
    if (_didScrollToSavedSpotListsSection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _savedSpotListsSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        setState(() {
          _didScrollToSavedSpotListsSection = true;
        });
      }
    });
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebMetaUtils.resetPageMeta();
    }
    super.dispose();
  }

  void _loadProfile() {
    final userProfileService = Provider.of<UserProfileService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid;
    _lastUserIdOrUsername = widget.userIdOrUsername;
    _profileFuture = userProfileService.getUserProfile(
      widget.userIdOrUsername,
      currentUserId: currentUserId,
    );
    // Force a rebuild to show the new data
    if (mounted) {
      setState(() {});
    }
  }

  bool _isOwnProfile(app_user.User user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser == null) return false;

    // Check if userIdOrUsername matches current user's ID or username
    if (widget.userIdOrUsername == currentUser.uid) return true;
    // Check if the profile's ID matches current user's ID (definitive check)
    if (user.id == currentUser.uid) return true;
    // Check if userIdOrUsername matches current user's username
    final currentUserProfile = authService.userProfile;
    if (currentUserProfile != null &&
        currentUserProfile.username != null &&
        currentUserProfile.username!.isNotEmpty &&
        widget.userIdOrUsername == currentUserProfile.username) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the future matches the current userIdOrUsername
    if (_lastUserIdOrUsername != widget.userIdOrUsername) {
      _loadProfile();
    }

    return FutureBuilder<app_user.User?>(
      key: ValueKey(
        widget.userIdOrUsername,
      ), // Force rebuild when userIdOrUsername changes
      future: _profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.displayName ?? _l10n.profileDefaultDisplayName;
        final userIdOrUsername =
            user?.username != null && user!.username!.isNotEmpty
            ? user.username!
            : user?.id ?? '';

        return PageScaffold(
          title: _l10n.publicProfilePageTitle,
          scrollable: false,
          actions: userIdOrUsername.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: _l10n.publicProfileShareProfileTooltip,
                    onPressed: () =>
                        _copyProfileToClipboard(userIdOrUsername, displayName),
                  ),
                ]
              : null,
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _l10n.publicProfileErrorLoadingProfile,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _l10n.publicProfilePleaseTryAgainLater,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(_l10n.spotDetailRouteGoToExplore),
                      ),
                    ],
                  ),
                );
              }

              final user = snapshot.data;

              if (user != null && kIsWeb) {
                final name =
                    user.displayName ??
                    user.username ??
                    _l10n.profileDefaultDisplayName;
                final description = _l10n.publicProfileMetaDescription(
                  name,
                  WebMetaUtils.defaultDescription,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    WebMetaUtils.updatePageMeta(
                      '$name - Parkour·Spot',
                      description,
                    );
                  }
                });
              } else if (user == null &&
                  snapshot.connectionState == ConnectionState.done &&
                  kIsWeb) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) WebMetaUtils.resetPageMeta();
                });
              }

              if (user == null) {
                // Profile not found or is private
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _l10n.publicProfileProfileNotFound,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _l10n.publicProfileNotFoundOrPrivate,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/explore'),
                        child: Text(_l10n.spotDetailRouteGoToExplore),
                      ),
                    ],
                  ),
                );
              }

              final isOwnProfile = _isOwnProfile(user);
              return _buildProfileContent(context, user, isOwnProfile);
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    app_user.User user,
    bool isOwnProfile,
  ) {
    // Layout (padding, max width, centering) comes from [PageScaffold].
    return SingleChildScrollView(
      child: Column(
        children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Private profile badge (only for own profile)
                          if (isOwnProfile && !user.isPublicProfile) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    spotListVisibilityDescription(
                                      _l10n,
                                      SpotListVisibility.private,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Profile Picture
                          Stack(
                            children: [
                              GestureDetector(
                                onTap:
                                    isOwnProfile && !_isUploadingProfilePicture
                                    ? _showProfilePictureOptions
                                    : null,
                                child: CircleAvatar(
                                  key: ValueKey(user.photoURL ?? 'no-photo'),
                                  radius: 50,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  backgroundImage:
                                      user.photoURL != null &&
                                          user.photoURL!.isNotEmpty
                                      ? NetworkImage(
                                          _getCacheBustedImageUrl(
                                            user.photoURL!,
                                          ),
                                        )
                                      : null,
                                  child: _isUploadingProfilePicture
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : (user.photoURL == null ||
                                            user.photoURL!.isEmpty)
                                      ? Text(
                                          user.displayName
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              'U',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                              ),
                                        )
                                      : null,
                                ),
                              ),
                              if (isOwnProfile && !_isUploadingProfilePicture)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // User Name
                          Text(
                            user.displayName ?? _l10n.profileDefaultDisplayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),

                          // Username (if set)
                          if (user.username != null &&
                              user.username!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],

                          if (user.instagramUrl != null &&
                              user.instagramUrl!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final handle =
                                    UrlService.extractInstagramHandle(
                                      user.instagramUrl!,
                                    );
                                return handle != null
                                    ? ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 350,
                                        ),
                                        child: InstagramButton(
                                          handle: handle,
                                          label: '@$handle',
                                        ),
                                      )
                                    : TextButton.icon(
                                        onPressed: () =>
                                            UrlService.openInstagramProfile(
                                              user.instagramUrl!,
                                              context,
                                            ),
                                        icon: const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          UrlService.getInstagramDisplayText(
                                            user.instagramUrl!,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      );
                              },
                            ),
                          ],

                          // Member since
                          if (user.createdAt != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _l10n.publicProfileMemberSince(
                                _formatDate(user.createdAt!),
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          ],

                          // User Stats
                          const SizedBox(height: 16),
                          _buildUserStats(context, user.id),
                        ],
                      ),
                      if (isOwnProfile)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: _l10n.publicProfileEditProfileTooltip,
                            onPressed: () =>
                                _showProfileSettingsSheet(context, user),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Spot tracking (Want to visit / Been to) - own profile only
              if (isOwnProfile) _buildSpotTrackingSection(context),

              // Spot lists (owned + saved from others when applicable)
              _buildSpotListsSection(
                context,
                profileUserId: user.id,
                isOwnProfile: isOwnProfile,
              ),
            ],
          ),
    );
  }

  Widget _buildSpotTrackingSection(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final wantToVisit = authService.userProfile?.wantToVisit ?? [];
        final visited = authService.userProfile?.visited ?? [];
        final wantCount = wantToVisit.length;
        final visitedCount = visited.length;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _l10n.publicProfileSpotTracking,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (wantCount == 0 && visitedCount == 0)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 40,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _l10n.publicProfileNoSpotsYet,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _l10n.publicProfileAddSpotsFromSpotDetailPages,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                          ),
                        ],
                      ),
                    ),
                  if (wantCount > 0)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.bookmark_outlined),
                        title: Text(_l10n.spotDetailWantToVisit),
                        subtitle: Text(
                          _spotCountLabel(wantCount),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                        onTap: () => context.push('/profile/want-to-visit'),
                      ),
                    ),
                  if (visitedCount > 0)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(_l10n.publicProfileBeenTo),
                        subtitle: Text(
                          _spotCountLabel(visitedCount),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                        onTap: () => context.push('/profile/visited'),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.how_to_reg_outlined),
                      title: Text(_l10n.publicProfileMyCheckIns),
                      subtitle: Text(
                        _l10n.publicProfileMyCheckInsSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                      onTap: () => context.push('/profile/check-ins'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpotListsSection(
    BuildContext context, {
    required String profileUserId,
    required bool isOwnProfile,
  }) {
    // Listen to AuthService so when userProfile / featureAccess loads after the first
    // frame we rebuild. Otherwise unifiedOwnAndSaved stays false and the Saved subsection
    // never appears (Consumer2 alone does not subscribe to AuthService).
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final featureAccessService = FeatureAccessService(authService);
        final canManageLists =
            isOwnProfile && featureAccessService.hasFeatureAccess('spotLists');
        // Unified card: owned + saved for any signed-in user on own profile (saved lists
        // are not gated on spotLists; Yours / + only when canManageLists).
        final unifiedSpotListsCard =
            isOwnProfile && authService.isAuthenticated;

        return Consumer2<SpotListService, SavedSpotListService>(
          builder: (context, spotListService, savedSpotListService, _) {
            return FutureBuilder<List<SpotList>>(
              future: spotListService.getSpotListsByUser(profileUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      key: unifiedSpotListsCard
                          ? _savedSpotListsSectionKey
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading lists: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ),
                  );
                }

                final lists = snapshot.data ?? [];

                if (lists.isEmpty && !isOwnProfile) {
                  return const SizedBox.shrink();
                }

                if (unifiedSpotListsCard) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      key: _savedSpotListsSectionKey,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _l10n.publicProfileSpotLists,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (canManageLists)
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: _l10n.spotDetailCreateNewList,
                                    onPressed: () => _showCreateListDialog(
                                      context,
                                      spotListService,
                                    ),
                                  ),
                              ],
                            ),
                            if (canManageLists || lists.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _l10n.publicProfileYours,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (lists.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.list_outlined,
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _l10n.spotDetailNoListsYet,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (canManageLists)
                                        TextButton(
                                          onPressed: () =>
                                              _showCreateListDialog(
                                                context,
                                                spotListService,
                                              ),
                                          child: Text(
                                            _l10n.publicProfileCreateYourFirstList,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: lists.map((list) {
                                    final visibilityAndCount =
                                        '${list.visibility.label} • ${list.spotCount} ${list.spotCount == 1 ? 'spot' : 'spots'}';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(list.name),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (list.description != null &&
                                                list.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  list.description!,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                visibilityAndCount,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                        ),
                                        onTap: () {
                                          if (list.id != null) {
                                            context.push('/list/${list.id}');
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 20),
                            ] else ...[
                              const SizedBox(height: 12),
                            ],
                            Text(
                              _l10n.publicProfileSaved,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildSavedSpotListsSubsection(
                              context,
                              savedSpotListService,
                              spotListService,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOwnProfile
                                    ? _l10n.publicProfileSpotLists
                                    : _l10n.publicProfilePublicSpotLists,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (canManageLists)
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: _l10n.spotDetailCreateNewList,
                                  onPressed: () => _showCreateListDialog(
                                    context,
                                    spotListService,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (lists.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.list_outlined,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _l10n.spotDetailNoListsYet,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (canManageLists)
                                    TextButton(
                                      onPressed: () => _showCreateListDialog(
                                        context,
                                        spotListService,
                                      ),
                                      child: Text(
                                        _l10n.publicProfileCreateYourFirstList,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Column(
                              children: lists.map((list) {
                                final visibilityAndCount =
                                    '${list.visibility.label} • ${list.spotCount} ${list.spotCount == 1 ? 'spot' : 'spots'}';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(list.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (list.description != null &&
                                            list.description!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              list.description!,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            visibilityAndCount,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      if (list.id != null) {
                                        context.push('/list/${list.id}');
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Saved lists subsection (stream + resolve). Used inside unified Spot lists card.
  Widget _buildSavedSpotListsSubsection(
    BuildContext context,
    SavedSpotListService savedSpotListService,
    SpotListService spotListService,
  ) {
    return StreamBuilder<List<String>>(
      stream: savedSpotListService.watchSavedListIdsOrdered(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final ids = snapshot.data ?? [];
        if (ids.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 48,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  _l10n.publicProfileNoSavedListsYet,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _l10n.publicProfileSaveListsHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<SpotList>>(
          key: ValueKey(ids.join(',')),
          future: savedSpotListService.resolveSavedListIds(
            spotListService,
            ids,
          ),
          builder: (context, listSnap) {
            if (listSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final savedLists = listSnap.data ?? [];
            if (savedLists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _l10n.publicProfileSavedListsUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              );
            }

            return Column(
              children: savedLists.map((list) {
                final visibilityAndCount =
                    '${list.visibility.label} • ${list.spotCount} ${list.spotCount == 1 ? 'spot' : 'spots'}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.bookmark,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(list.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (list.description != null &&
                            list.description!.isNotEmpty)
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
                            visibilityAndCount,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (list.id != null) {
                        context.push('/list/${list.id}');
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _showCreateListDialog(
    BuildContext context,
    SpotListService spotListService,
  ) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    SpotListVisibility selectedVisibility = SpotListVisibility.unlisted;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_l10n.spotDetailCreateNewList),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailListNameLabel,
                    hintText: _l10n.spotDetailListNameHint,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailListDescriptionLabel,
                    hintText: _l10n.spotDetailListDescriptionHint,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SpotListVisibility>(
                  initialValue: selectedVisibility,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailVisibilityLabel,
                  ),
                  items: SpotListVisibility.values
                      .map(
                        (visibility) => DropdownMenuItem<SpotListVisibility>(
                          value: visibility,
                          child: Text(visibility.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedVisibility = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selectedVisibility.description,
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_l10n.profileCancel),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(_l10n.spotDetailListNameEmpty)),
                  );
                  return;
                }

                final listId = await spotListService.createSpotList(
                  nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  visibility: selectedVisibility,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  if (listId != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_l10n.publicProfileListCreatedSuccessfully),
                      ),
                    );
                  } else if (spotListService.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(spotListService.error!)),
                    );
                  }
                }
              },
              child: Text(_l10n.spotDetailCreateButton),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSettingsSheet(BuildContext context, app_user.User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) =>
                _ProfileSettingsSheetContent(
                  user: user,
                  userIdOrUsername: widget.userIdOrUsername,
                  scrollController: scrollController,
                  onSaved: () {
                    Navigator.pop(sheetContext);
                    _loadProfile();
                  },
                  onUsernameRedirect: (String newUsername) {
                    Navigator.pop(sheetContext);
                    context.go('/user/$newUsername');
                  },
                ),
          ),
        ),
      ),
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
        title: Text(_l10n.publicProfileChangeProfilePicture),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_l10n.publicProfileChooseFromGallery),
              onTap: () {
                Navigator.pop(dialogContext);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(_l10n.publicProfileTakePhoto),
              onTap: () {
                Navigator.pop(dialogContext);
                _takePhoto();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  _l10n.publicProfileRemovePicture,
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
            child: Text(_l10n.profileCancel),
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
            content: Text(_l10n.publicProfileErrorPickingImage(e.toString())),
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
            content: Text(_l10n.publicProfileErrorTakingPhoto(e.toString())),
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
    String statusMessage = _l10n.publicProfileProcessingImage;

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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
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
        updateProgress(0.1, _l10n.publicProfileReadingImage);
        final bytes = await pickedFile.readAsBytes();

        // Upload with progress updates
        photoURL = await _profilePictureService.uploadProfilePictureBytes(
          bytes,
          onProgress: (progress) {
            String message;
            if (progress < 0.3) {
              message = _l10n.publicProfileProcessingImage;
            } else if (progress < 0.9) {
              message = _l10n.publicProfileUploading;
            } else {
              message = _l10n.publicProfileFinishing;
            }
            updateProgress(progress, message);
          },
        );
      } else {
        // Mobile: use File
        updateProgress(0.1, _l10n.publicProfileReadingImage);
        final file = File(pickedFile.path);

        // Upload with progress updates
        photoURL = await _profilePictureService.uploadProfilePicture(
          file,
          onProgress: (progress) {
            String message;
            if (progress < 0.3) {
              message = _l10n.publicProfileProcessingImage;
            } else if (progress < 0.9) {
              message = _l10n.publicProfileUploading;
            } else {
              message = _l10n.publicProfileFinishing;
            }
            updateProgress(progress, message);
          },
        );
      }

      // Update profile
      updateProgress(0.95, _l10n.publicProfileUpdatingProfile);
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
          // Refresh profile
          final userProfileService = Provider.of<UserProfileService>(
            context,
            listen: false,
          );
          final currentUserId = authService.currentUser?.uid;
          _lastUserIdOrUsername = widget.userIdOrUsername;
          _profileFuture = userProfileService.getUserProfile(
            widget.userIdOrUsername,
            currentUserId: currentUserId,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.publicProfileProfilePictureUpdatedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.publicProfileFailedToUpdateProfilePicture),
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
            content: Text(
              _l10n.publicProfileErrorUploadingProfilePicture(e.toString()),
            ),
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
        title: Text(_l10n.publicProfileRemoveProfilePicture),
        content: Text(_l10n.publicProfileRemoveProfilePictureConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.profileCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_l10n.spotDetailRemoveButton),
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
          // Refresh profile
          final userProfileService = Provider.of<UserProfileService>(
            context,
            listen: false,
          );
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUserId = authService.currentUser?.uid;
          _lastUserIdOrUsername = widget.userIdOrUsername;
          _profileFuture = userProfileService.getUserProfile(
            widget.userIdOrUsername,
            currentUserId: currentUserId,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.publicProfileProfilePictureRemovedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.publicProfileFailedToRemoveProfilePicture),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _l10n.publicProfileErrorRemovingProfilePicture(e.toString()),
            ),
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

  String _formatDate(DateTime date) {
    final localeName = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMM(localeName).format(date);
  }

  void _copyProfileToClipboard(
    String userIdOrUsername,
    String displayName,
  ) async {
    try {
      final url = UrlService.generateUserProfileUrl(userIdOrUsername);
      final text = '$displayName 👉 $url';

      final outcome =
          await WebShareService.tryShareLink(text: displayName, url: url);
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.publicProfileProfileCopiedToClipboard),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.publicProfileFailedToCopyProfile(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildUserStats(BuildContext context, String userId) {
    final userProfileService = UserProfileService();

    return FutureBuilder<Map<String, int>?>(
      future: userProfileService.getUserStats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final spotsCount = stats['spotsCreated'] ?? 0;
        final ratingsCount = stats['ratings'] ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              context,
              Icons.add_location,
              spotsCount,
              _l10n.publicProfileStatsSpots,
            ),
            _buildStatItem(
              context,
              Icons.star,
              ratingsCount,
              _l10n.publicProfileStatsRatings,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    int count,
    String label,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Add cache-busting query parameter to image URL
  String _getCacheBustedImageUrl(String url) {
    try {
      final uri = Uri.parse(url);

      final isFirebaseStorage =
          url.contains('firebasestorage.googleapis.com') ||
          url.contains('storage.googleapis.com');

      final version = isFirebaseStorage
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : url.hashCode.toString();

      final cacheBustedUri = uri.replace(
        queryParameters: {...uri.queryParameters, 'v': version},
      );
      return cacheBustedUri.toString();
    } catch (e) {
      final separator = url.contains('?') ? '&' : '?';
      final isFirebaseStorage =
          url.contains('firebasestorage.googleapis.com') ||
          url.contains('storage.googleapis.com');
      final version = isFirebaseStorage
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : url.hashCode.toString();
      return '$url${separator}v=$version';
    }
  }
}

class _ProfileSettingsSheetContent extends StatefulWidget {
  final app_user.User user;
  final String userIdOrUsername;
  final ScrollController scrollController;
  final VoidCallback onSaved;
  final void Function(String newUsername) onUsernameRedirect;

  const _ProfileSettingsSheetContent({
    required this.user,
    required this.userIdOrUsername,
    required this.scrollController,
    required this.onSaved,
    required this.onUsernameRedirect,
  });

  @override
  State<_ProfileSettingsSheetContent> createState() =>
      _ProfileSettingsSheetContentState();
}

class _ProfileSettingsSheetContentState
    extends State<_ProfileSettingsSheetContent> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _instagramUrlController;
  bool _isEditingDisplayName = false;
  bool _isUpdatingDisplayName = false;
  String? _displayNameError;
  bool _isEditingUsername = false;
  bool _isCheckingUsername = false;
  String? _usernameError;
  bool _isEditingInstagramUrl = false;
  bool _isUpdatingInstagramUrl = false;
  String? _instagramUrlError;

  static const int _displayNameMaxLength = 50;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName?.trim() ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.user.username ?? '',
    );
    _instagramUrlController = TextEditingController(
      text: widget.user.instagramUrl?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _instagramUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text(
                _l10n.publicProfileSettingsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: _l10n.spotDetailClose,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.user.email.isNotEmpty) ...[
                  _buildEmailSection(context),
                  const SizedBox(height: 16),
                ],
                _buildDisplayNameSection(context),
                const SizedBox(height: 16),
                _buildUsernameSection(context),
                const SizedBox(height: 16),
                _buildInstagramSection(context),
                const SizedBox(height: 16),
                _buildPrivacySection(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.publicProfileEmailLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          widget.user.email,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _l10n.publicProfileEmailNotShownHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayNameSection(BuildContext context) {
    final user = widget.user;
    final currentDisplayName = user.displayName?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.publicProfileDisplayNameLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (!_isEditingDisplayName) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  currentDisplayName.isNotEmpty
                      ? currentDisplayName
                      : _l10n.publicProfileNoDisplayNameSet,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingDisplayName = true;
                    _displayNameController.text = currentDisplayName;
                    _displayNameError = null;
                  });
                },
                child: Text(_l10n.publicProfileEditAction),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: _l10n.publicProfileDisplayNameLabel,
              hintText: _l10n.publicProfileDisplayNameHint,
              errorText: _displayNameError,
              helperText: _l10n.publicProfileDisplayNameHelper(
                _displayNameMaxLength,
              ),
            ),
            enabled: !_isUpdatingDisplayName,
            maxLength: _displayNameMaxLength,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isUpdatingDisplayName
                    ? null
                    : () {
                        setState(() {
                          _isEditingDisplayName = false;
                          _displayNameController.text = currentDisplayName;
                          _displayNameError = null;
                        });
                      },
                child: Text(_l10n.profileCancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUpdatingDisplayName
                    ? null
                    : () async {
                        final rawInput = _displayNameController.text.trim();
                        final newDisplayName = rawInput.isEmpty
                            ? null
                            : rawInput;

                        if (rawInput.length > _displayNameMaxLength) {
                          setState(() {
                            _displayNameError =
                                _l10n.publicProfileDisplayNameMaxLengthError(
                              _displayNameMaxLength,
                            );
                          });
                          return;
                        }

                        setState(() {
                          _isUpdatingDisplayName = true;
                          _displayNameError = null;
                        });

                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        final success = await authService.updateProfile(
                          displayName: newDisplayName,
                          removeDisplayName: newDisplayName == null,
                        );

                        if (!mounted) return;

                        setState(() {
                          _isUpdatingDisplayName = false;
                        });

                        if (success) {
                          setState(() {
                            _isEditingDisplayName = false;
                            _displayNameError = null;
                          });
                          widget.onSaved();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newDisplayName != null
                                    ? _l10n.publicProfileDisplayNameUpdated
                                    : _l10n.publicProfileDisplayNameRemoved,
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _displayNameError =
                                _l10n.publicProfileDisplayNameUpdateFailed;
                          });
                        }
                      },
                child: _isUpdatingDisplayName
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_l10n.publicProfileSaveAction),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildUsernameSection(BuildContext context) {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.publicProfileUsernameLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (!_isEditingUsername) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  user.username != null && user.username!.isNotEmpty
                      ? '@${user.username}'
                      : _l10n.publicProfileNoUsernameSet,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingUsername = true;
                    _usernameController.text = user.username ?? '';
                    _usernameError = null;
                  });
                },
                child: Text(_l10n.publicProfileEditAction),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: _l10n.publicProfileUsernameLabel,
              hintText: _l10n.publicProfileUsernameHint,
              errorText: _usernameError,
              prefixText: '@',
              helperText: _l10n.publicProfileUsernameHelper,
            ),
            enabled: !_isCheckingUsername,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isCheckingUsername
                    ? null
                    : () {
                        setState(() {
                          _isEditingUsername = false;
                          _usernameController.text = user.username ?? '';
                          _usernameError = null;
                        });
                      },
                child: Text(_l10n.profileCancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isCheckingUsername
                    ? null
                    : () async {
                        final newUsername = _usernameController.text.trim();

                        if (newUsername.isEmpty) {
                          setState(() {
                            _usernameError = _l10n.publicProfileUsernameEmpty;
                          });
                          return;
                        }

                        setState(() {
                          _isCheckingUsername = true;
                          _usernameError = null;
                        });

                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        final userProfileService =
                            Provider.of<UserProfileService>(
                              context,
                              listen: false,
                            );

                        final isAvailable = await authService
                            .checkUsernameAvailability(newUsername);

                        if (!isAvailable &&
                            newUsername.toLowerCase() !=
                                user.username?.toLowerCase()) {
                          if (mounted) {
                            setState(() {
                              _isCheckingUsername = false;
                              _usernameError =
                                  _l10n.publicProfileUsernameTaken;
                            });
                          }
                          return;
                        }

                        final success = await authService.updateUsername(
                          newUsername,
                        );

                        if (!mounted) return;

                        setState(() {
                          _isCheckingUsername = false;
                        });

                        if (success) {
                          final isViewingByUsername =
                              widget.userIdOrUsername.length != 28;
                          final usernameChanged =
                              newUsername.toLowerCase() !=
                              user.username?.toLowerCase();

                          if (isViewingByUsername && usernameChanged) {
                            widget.onUsernameRedirect(newUsername);
                          } else {
                            widget.onSaved();
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_l10n.publicProfileUsernameUpdated),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _usernameError =
                                userProfileService.error ??
                                _l10n.publicProfileUsernameUpdateFailed;
                          });
                        }
                      },
                child: _isCheckingUsername
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_l10n.publicProfileSaveAction),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInstagramSection(BuildContext context) {
    final user = widget.user;
    final currentInstagramUrl = user.instagramUrl?.trim() ?? '';
    final hasInstagramUrl = currentInstagramUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.publicProfileInstagramLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (!_isEditingInstagramUrl) ...[
          Row(
            children: [
              Expanded(
                child: hasInstagramUrl
                    ? InkWell(
                        onTap: () => UrlService.openInstagramProfile(
                          currentInstagramUrl,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            UrlService.getInstagramDisplayText(
                              currentInstagramUrl,
                            ),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      )
                    : Text(
                        _l10n.publicProfileNoInstagramSet,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingInstagramUrl = true;
                    _instagramUrlController.text = currentInstagramUrl;
                    _instagramUrlError = null;
                  });
                },
                child: Text(
                  hasInstagramUrl
                      ? _l10n.publicProfileEditAction
                      : _l10n.publicProfileAddAction,
                ),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _instagramUrlController,
            decoration: InputDecoration(
              labelText: _l10n.publicProfileInstagramLinkLabel,
              hintText: _l10n.publicProfileInstagramLinkHint,
              helperText: _l10n.publicProfileInstagramLinkHelper,
              errorText: _instagramUrlError,
            ),
            enabled: !_isUpdatingInstagramUrl,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isUpdatingInstagramUrl
                    ? null
                    : () {
                        setState(() {
                          _isEditingInstagramUrl = false;
                          _instagramUrlController.text = currentInstagramUrl;
                          _instagramUrlError = null;
                        });
                      },
                child: Text(_l10n.profileCancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUpdatingInstagramUrl
                    ? null
                    : () async {
                        final rawInput = _instagramUrlController.text.trim();
                        final normalizedInstagramUrl = rawInput.isEmpty
                            ? null
                            : UrlService.normalizeInstagramProfileUrl(rawInput);

                        if (rawInput.isNotEmpty &&
                            normalizedInstagramUrl == null) {
                          setState(() {
                            _instagramUrlError =
                                _l10n.publicProfileInstagramInvalid;
                          });
                          return;
                        }

                        setState(() {
                          _isUpdatingInstagramUrl = true;
                          _instagramUrlError = null;
                        });

                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        final success = await authService.updateProfile(
                          instagramUrl: normalizedInstagramUrl,
                          removeInstagramUrl: rawInput.isEmpty,
                        );

                        if (!mounted) return;

                        setState(() {
                          _isUpdatingInstagramUrl = false;
                        });

                        if (success) {
                          setState(() {
                            _isEditingInstagramUrl = false;
                            _instagramUrlError = null;
                          });
                          widget.onSaved();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                rawInput.isEmpty
                                    ? _l10n.publicProfileInstagramRemoved
                                    : _l10n.publicProfileInstagramUpdated,
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _instagramUrlError =
                                _l10n.publicProfileInstagramUpdateFailed;
                          });
                        }
                      },
                child: _isUpdatingInstagramUrl
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_l10n.publicProfileSaveAction),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    final user = widget.user;
    final isPublic = user.isPublicProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.publicProfilePrivacyTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPublic
                        ? _l10n.publicProfilePrivacyPublicLabel
                        : _l10n.publicProfilePrivacyPrivateLabel,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPublic
                        ? _l10n.publicProfilePrivacyPublicDescription
                        : _l10n.publicProfilePrivacyPrivateDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isPublic,
              onChanged: (value) async {
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final success = await authService.updateProfilePrivacy(value);
                if (mounted) {
                  if (success) {
                    widget.onSaved();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? _l10n.publicProfilePrivacyNowPublic
                              : _l10n.publicProfilePrivacyNowPrivate,
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _l10n.publicProfileFailedToUpdateProfilePrivacy,
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
