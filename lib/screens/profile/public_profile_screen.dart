import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_picture_service.dart';
import '../../services/url_service.dart';
import '../../models/user.dart' as app_user;
import '../../models/spot_list.dart';
import '../../services/spot_list_service.dart';
import '../../services/feature_access_service.dart';
import '../../widgets/instagram_button.dart';
import '../../utils/web_meta_utils.dart';
import '../../widgets/page_scaffold.dart';
import 'package:flutter/services.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userIdOrUsername;

  const PublicProfileScreen({
    super.key,
    required this.userIdOrUsername,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Future<app_user.User?>? _profileFuture;
  String? _lastUserIdOrUsername; // Track the last userIdOrUsername used to create the future
  bool _isUploadingProfilePicture = false;
  final ProfilePictureService _profilePictureService = ProfilePictureService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset future if userIdOrUsername has changed
    if (_profileFuture == null || _lastUserIdOrUsername != widget.userIdOrUsername) {
      _loadProfile();
    }
  }

  @override
  void didUpdateWidget(PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If userIdOrUsername changed, reload the profile
    if (oldWidget.userIdOrUsername != widget.userIdOrUsername) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebMetaUtils.resetPageMeta();
    }
    super.dispose();
  }

  void _loadProfile() {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
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
      key: ValueKey(widget.userIdOrUsername), // Force rebuild when userIdOrUsername changes
      future: _profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.displayName ?? 'User';
        final userIdOrUsername = user?.username != null && user!.username!.isNotEmpty
            ? user.username!
            : user?.id ?? '';
        
        return PageScaffold(
          title: 'Profile',
          actions: userIdOrUsername.isNotEmpty ? [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Profile',
              onPressed: () => _copyProfileToClipboard(userIdOrUsername, displayName),
            ),
          ] : null,
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Go to Explore'),
                  ),
                ],
              ),
                );
              }

              final user = snapshot.data;

              if (user != null && kIsWeb) {
                final name = user.displayName ?? user.username ?? 'User';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    WebMetaUtils.updatePageMeta(
                      '$name - Parkour·Spot',
                      "View $name's parkour spots and lists on Parkour·Spot",
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
                      const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Profile not found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This profile does not exist or is private.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/explore'),
                        child: const Text('Go to Explore'),
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

  Widget _buildProfileContent(BuildContext context, app_user.User user, bool isOwnProfile) {
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
                  child: Stack(
                    children: [
                      Column(
                        children: [
                      // Private profile badge (only for own profile)
                      if (isOwnProfile && !user.isPublicProfile) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Only visible to you',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
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
                            onTap: isOwnProfile && !_isUploadingProfilePicture
                                ? _showProfilePictureOptions
                                : null,
                            child: CircleAvatar(
                              key: ValueKey(user.photoURL ?? 'no-photo'),
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                                  ? NetworkImage(_getCacheBustedImageUrl(user.photoURL!))
                                  : null,
                              child: _isUploadingProfilePicture
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : (user.photoURL == null || user.photoURL!.isEmpty)
                                      ? Text(
                                          user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
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
                        user.displayName ?? 'User',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      // Username (if set)
                      if (user.username != null && user.username!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],

                      if (user.instagramUrl != null && user.instagramUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final handle = UrlService.extractInstagramHandle(user.instagramUrl!);
                            return handle != null
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 350),
                                    child: InstagramButton(
                                      handle: handle,
                                      label: '@$handle',
                                    ),
                                  )
                                : TextButton.icon(
                                    onPressed: () => UrlService.openInstagramProfile(user.instagramUrl!, context),
                                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                    label: Text(UrlService.getInstagramDisplayText(user.instagramUrl!)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context).colorScheme.primary,
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
                          'Member since ${_formatDate(user.createdAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                            tooltip: 'Edit Profile',
                            onPressed: () => _showProfileSettingsSheet(context, user),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Spot Lists
              _buildSpotListsSection(
                context,
                profileUserId: user.id,
                isOwnProfile: isOwnProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotListsSection(
    BuildContext context, {
    required String profileUserId,
    required bool isOwnProfile,
  }) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final featureAccessService = FeatureAccessService(authService);
    final canManageLists =
        isOwnProfile && featureAccessService.hasFeatureAccess('spotLists');

    return Consumer<SpotListService>(
      builder: (context, spotListService, child) {
        return FutureBuilder<List<SpotList>>(
          future: spotListService.getSpotListsByUser(profileUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isOwnProfile ? 'Spot Lists' : 'Public Spot Lists',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (canManageLists)
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Create New List',
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
                                'No lists yet',
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
                                  child: const Text('Create your first list'),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (list.description != null &&
                                        list.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          list.description!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
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
                                trailing: canManageLists
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            tooltip: 'Edit',
                                            onPressed: list.id == null
                                                ? null
                                                : () => _showEditListDialog(
                                                      context,
                                                      spotListService,
                                                      list,
                                                    ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: 'Delete',
                                            onPressed: list.id == null
                                                ? null
                                                : () => _showDeleteListDialog(
                                                      context,
                                                      spotListService,
                                                      list,
                                                    ),
                                          ),
                                        ],
                                      )
                                    : null,
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
          title: const Text('Create New List'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 16),
                DropdownButtonFormField<SpotListVisibility>(
                  value: selectedVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
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
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
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
                  visibility: selectedVisibility,
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
      ),
    );
  }

  void _showEditListDialog(
    BuildContext context,
    SpotListService spotListService,
    SpotList list,
  ) {
    final nameController = TextEditingController(text: list.name);
    final descriptionController = TextEditingController(text: list.description ?? '');
    SpotListVisibility selectedVisibility = list.visibility;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit List'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 16),
                DropdownButtonFormField<SpotListVisibility>(
                  value: selectedVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
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
                    style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
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
                  visibility: selectedVisibility,
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
            builder: (context, scrollController) => _ProfileSettingsSheetContent(
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
          // Refresh profile
          final userProfileService = Provider.of<UserProfileService>(context, listen: false);
          final currentUserId = authService.currentUser?.uid;
          _lastUserIdOrUsername = widget.userIdOrUsername;
          _profileFuture = userProfileService.getUserProfile(
            widget.userIdOrUsername,
            currentUserId: currentUserId,
          );
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
          // Refresh profile
          final userProfileService = Provider.of<UserProfileService>(context, listen: false);
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUserId = authService.currentUser?.uid;
          _lastUserIdOrUsername = widget.userIdOrUsername;
          _profileFuture = userProfileService.getUserProfile(
            widget.userIdOrUsername,
            currentUserId: currentUserId,
          );
          
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

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _copyProfileToClipboard(String userIdOrUsername, String displayName) async {
    try {
      final url = UrlService.generateUserProfileUrl(userIdOrUsername);
      final text = '$displayName 👉 $url';

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy profile: $e'),
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
            _buildStatItem(context, Icons.add_location, spotsCount, 'Spots'),
            _buildStatItem(context, Icons.star, ratingsCount, 'Ratings'),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
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
        text: widget.user.displayName?.trim() ?? '');
    _usernameController = TextEditingController(text: widget.user.username ?? '');
    _instagramUrlController =
        TextEditingController(text: widget.user.instagramUrl?.trim() ?? '');
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
                'Profile Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
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
          'Email',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.user.email,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your email is not shown on your public profile.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
          'Display Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!_isEditingDisplayName) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  currentDisplayName.isNotEmpty
                      ? currentDisplayName
                      : 'No display name set',
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
                child: const Text('Edit'),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your display name',
              errorText: _displayNameError,
              helperText: 'Shown on your profile and spots you create '
                  '(max $_displayNameMaxLength characters)',
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
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUpdatingDisplayName
                    ? null
                    : () async {
                        final rawInput =
                            _displayNameController.text.trim();
                        final newDisplayName =
                            rawInput.isEmpty ? null : rawInput;

                        if (rawInput.length > _displayNameMaxLength) {
                          setState(() {
                            _displayNameError =
                                'Display name must be at most '
                                '$_displayNameMaxLength characters';
                          });
                          return;
                        }

                        setState(() {
                          _isUpdatingDisplayName = true;
                          _displayNameError = null;
                        });

                        final authService =
                            Provider.of<AuthService>(context, listen: false);
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
                                    ? 'Display name updated successfully'
                                    : 'Display name removed',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _displayNameError =
                                'Failed to update display name';
                          });
                        }
                      },
                child: _isUpdatingDisplayName
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
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
          'Username',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!_isEditingUsername) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  user.username != null && user.username!.isNotEmpty
                      ? '@${user.username}'
                      : 'No username set',
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
                child: const Text('Edit'),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Enter username',
              errorText: _usernameError,
              prefixText: '@',
              helperText:
                  '3-27 characters, letters, numbers, underscores, and hyphens only',
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
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isCheckingUsername
                    ? null
                    : () async {
                        final newUsername =
                            _usernameController.text.trim();

                        if (newUsername.isEmpty) {
                          setState(() {
                            _usernameError = 'Username cannot be empty';
                          });
                          return;
                        }

                        setState(() {
                          _isCheckingUsername = true;
                          _usernameError = null;
                        });

                        final authService =
                            Provider.of<AuthService>(context, listen: false);
                        final userProfileService =
                            Provider.of<UserProfileService>(context,
                                listen: false);

                        final isAvailable =
                            await authService.checkUsernameAvailability(
                                newUsername);

                        if (!isAvailable &&
                            newUsername.toLowerCase() !=
                                user.username?.toLowerCase()) {
                          if (mounted) {
                            setState(() {
                              _isCheckingUsername = false;
                              _usernameError = 'Username is already taken';
                            });
                          }
                          return;
                        }

                        final success =
                            await authService.updateUsername(newUsername);

                        if (!mounted) return;

                        setState(() {
                          _isCheckingUsername = false;
                        });

                        if (success) {
                          final isViewingByUsername =
                              widget.userIdOrUsername.length != 28;
                          final usernameChanged = newUsername.toLowerCase() !=
                              user.username?.toLowerCase();

                          if (isViewingByUsername && usernameChanged) {
                            widget.onUsernameRedirect(newUsername);
                          } else {
                            widget.onSaved();
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Username updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _usernameError = userProfileService.error ??
                                'Failed to update username';
                          });
                        }
                      },
                child: _isCheckingUsername
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
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
          'Instagram',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!_isEditingInstagramUrl) ...[
          Row(
            children: [
              Expanded(
                child: hasInstagramUrl
                    ? InkWell(
                        onTap: () => UrlService.openInstagramProfile(
                            currentInstagramUrl, context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            UrlService.getInstagramDisplayText(
                                currentInstagramUrl),
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      )
                    : Text(
                        'No Instagram link set',
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
                child: Text(hasInstagramUrl ? 'Edit' : 'Add'),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _instagramUrlController,
            decoration: InputDecoration(
              labelText: 'Instagram Link',
              hintText: 'https://www.instagram.com/your_handle/',
              helperText:
                  'You can also paste @handle or just the handle',
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
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isUpdatingInstagramUrl
                    ? null
                    : () async {
                        final rawInput =
                            _instagramUrlController.text.trim();
                        final normalizedInstagramUrl = rawInput.isEmpty
                            ? null
                            : UrlService.normalizeInstagramProfileUrl(
                                rawInput);

                        if (rawInput.isNotEmpty &&
                            normalizedInstagramUrl == null) {
                          setState(() {
                            _instagramUrlError =
                                'Enter a valid Instagram profile URL or handle';
                          });
                          return;
                        }

                        setState(() {
                          _isUpdatingInstagramUrl = true;
                          _instagramUrlError = null;
                        });

                        final authService =
                            Provider.of<AuthService>(context, listen: false);
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
                                    ? 'Instagram link removed'
                                    : 'Instagram link updated successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            _instagramUrlError =
                                'Failed to update Instagram link';
                          });
                        }
                      },
                child: _isUpdatingInstagramUrl
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
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
          'Profile Privacy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPublic ? 'Public Profile' : 'Private Profile',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPublic
                        ? 'Your profile is visible to everyone'
                        : 'Your profile is private and not visible to others',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isPublic,
              onChanged: (value) async {
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                final success =
                    await authService.updateProfilePrivacy(value);
                if (mounted) {
                  if (success) {
                    widget.onSaved();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Profile is now public'
                              : 'Profile is now private',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Failed to update profile privacy'),
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
