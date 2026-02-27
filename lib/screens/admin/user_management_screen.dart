import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart' as app_user;
import '../../services/auth_service.dart';
import '../../services/user_management_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<UserManagementService>();
      if (service.users.isEmpty && !service.isLoading) {
        service.fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = context.select<AuthService, bool>((service) => service.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Management')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/admin');
          }
        },
        ),
        actions: [
          Consumer<UserManagementService>(
            builder: (context, service, _) {
              final isBusy =
                  service.isSyncingCreatedAt ||
                  service.isCopyingGoogleAvatars ||
                  service.isMakingProfilePicturesPublic ||
                  service.isSyncingSpotDisplayNames;
              return PopupMenuButton<String>(
                icon: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'sync_created_at') {
                    await _syncUserCreatedAt(context, service, dryRun: false);
                  } else if (value == 'sync_created_at_dry_run') {
                    await _syncUserCreatedAt(context, service, dryRun: true);
                  } else if (value == 'copy_google_avatars_dry_run') {
                    await _copyGoogleAvatars(context, service, dryRun: true);
                  } else if (value == 'copy_google_avatars') {
                    await _copyGoogleAvatars(context, service, dryRun: false);
                  } else if (value == 'make_profile_pictures_public') {
                    await _makeProfilePicturesPublic(context, service);
                  } else if (value == 'sync_spot_display_names_dry_run') {
                    await _syncSpotDisplayNames(context, service, dryRun: true);
                  } else if (value == 'sync_spot_display_names') {
                    await _syncSpotDisplayNames(context, service, dryRun: false);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sync_created_at_dry_run',
                    child: Row(
                      children: [
                        Icon(Icons.preview, size: 20),
                        SizedBox(width: 8),
                        Text('Preview Sync CreatedAt'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sync_created_at',
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 20),
                        SizedBox(width: 8),
                        Text('Sync CreatedAt from Auth'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'copy_google_avatars_dry_run',
                    child: Row(
                      children: [
                        Icon(Icons.preview, size: 20),
                        SizedBox(width: 8),
                        Text('Preview Copy Google Avatars'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_google_avatars',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('Copy Google Avatars to Storage'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'make_profile_pictures_public',
                    child: Row(
                      children: [
                        Icon(Icons.public, size: 20),
                        SizedBox(width: 8),
                        Text('Make profile pictures public'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'sync_spot_display_names_dry_run',
                    child: Row(
                      children: [
                        Icon(Icons.preview, size: 20),
                        SizedBox(width: 8),
                        Text('Preview Sync Spot Display Names'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sync_spot_display_names',
                    child: Row(
                      children: [
                        Icon(Icons.badge, size: 20),
                        SizedBox(width: 8),
                        Text('Sync Spot Display Names'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Consumer<UserManagementService>(
            builder: (context, service, _) {
              return IconButton(
                tooltip: 'Refresh',
                icon: service.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: service.isLoading
                    ? null
                    : () => service.fetchUsers(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Search users',
                hintText: 'Search by name or email',
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: Consumer<UserManagementService>(
              builder: (context, service, _) {
                if (service.isLoading && service.users.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (service.error != null && service.users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(service.error!, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                final List<app_user.User> filteredUsers = (_searchTerm.isEmpty
                    ? List<app_user.User>.from(service.users)
                    : service.users.where((user) {
                        final name = user.displayName?.toLowerCase() ?? '';
                        final email = user.email.toLowerCase();
                        return name.contains(_searchTerm) || email.contains(_searchTerm);
                      }).toList())
                  ..sort((a, b) {
                    // Sort by createdAt in reverse chronological order (newest first)
                    // Users without createdAt go to the end
                    if (a.createdAt == null && b.createdAt == null) return 0;
                    if (a.createdAt == null) return 1;
                    if (b.createdAt == null) return -1;
                    return b.createdAt!.compareTo(a.createdAt!);
                  });

                if (filteredUsers.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => service.fetchUsers(forceRefresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 120),
                          child: Column(
                            children: const [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No users found'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => service.fetchUsers(forceRefresh: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final profilePath = _profilePathForUser(user);
                      return Card(
                        child: ListTile(
                          leading: _UserAvatar(user: user),
                          title: SelectableText(user.displayName?.isNotEmpty == true ? user.displayName! : user.email),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(user.email),
                              if (user.createdAt != null)
                                Text(
                                  'Joined: ${_formatDate(user.createdAt!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              InkWell(
                                onTap: () => _openUserProfile(user),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                                  child: Text(
                                    profilePath,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (user.isAdmin)
                                const Chip(
                                  label: Text('Admin'),
                                  backgroundColor: Color(0xFFE3F2FD),
                                ),
                              if (user.isModerator)
                                const Chip(
                                  label: Text('Moderator'),
                                  backgroundColor: Color(0xFFE8F5E9),
                                ),
                            ],
                          ),
                          onTap: () => _openUserDetail(user),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUserDetail(app_user.User initialUser) async {
    if (!mounted) return;

    final rootContext = context;
    final service = rootContext.read<UserManagementService>();
    // Kick off stats loading but don't wait for completion to keep UI responsive.
    service.loadUserStats(initialUser.id);

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Consumer<UserManagementService>(
              builder: (context, userService, _) {
                app_user.User user;
                try {
                  user = userService.users.firstWhere((candidate) => candidate.id == initialUser.id);
                } catch (_) {
                  user = initialUser;
                }

                final stats = userService.getStats(user.id);
                final statsError = userService.statsError(user.id);
                final bool statsLoading = userService.isLoadingStats(user.id);
                final bool updatingModerator = userService.isUpdatingModerator(user.id);
                final bool updatingFeatureAccess = userService.isUpdatingFeatureAccess(user.id);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _UserAvatar(user: user, radius: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  user.displayName?.isNotEmpty == true ? user.displayName! : user.email,
                                  style: Theme.of(sheetContext).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                SelectableText(user.email),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Activity',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (statsLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (statsError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statsError, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => userService.loadUserStats(user.id, forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (stats != null)
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                label: 'Spots created',
                                value: stats.spotsCreated.toString(),
                                icon: Icons.place,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                label: 'Spot reports',
                                value: stats.spotReports.toString(),
                                icon: Icons.report,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                label: 'Ratings',
                                value: stats.ratings.toString(),
                                icon: Icons.star_rate,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const Text('No statistics available.'),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => userService.loadUserStats(user.id, forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Load stats'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Permissions',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: user.isModerator,
                        title: const Text('Moderator access'),
                        subtitle: const Text('Allow this user to manage spot reports and moderation tools.'),
                        secondary: const Icon(Icons.security),
                        contentPadding: EdgeInsets.zero,
                        onChanged: updatingModerator
                            ? null
                            : (value) async {
                                final bool success = await userService.updateModeratorStatus(user.id, value);
                                if (!mounted) return;

                                if (success) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(
                                      content: Text(value
                                          ? 'Moderator access granted to ${user.displayName ?? user.email}'
                                          : 'Moderator access removed from ${user.displayName ?? user.email}'),
                                      backgroundColor: value ? Colors.green : Colors.orange,
                                    ),
                                  );
                                } else {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(
                                      content: const Text('Failed to update moderator status'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                      if (updatingModerator)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Feature Access',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _FeatureAccessSection(
                        user: user,
                        userService: userService,
                        updatingFeatureAccess: updatingFeatureAccess,
                        rootContext: rootContext,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _profilePathForUser(app_user.User user) {
    final username = user.username?.trim();
    final identifier = username != null && username.isNotEmpty ? username : user.id;
    return '/user/$identifier';
  }

  void _openUserProfile(app_user.User user) {
    if (!mounted) return;
    context.push(_profilePathForUser(user));
  }

  String _formatTimestamp(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} UTC';
    } catch (e) {
      return isoString;
    }
  }

  Future<void> _syncUserCreatedAt(
    BuildContext context,
    UserManagementService service, {
    required bool dryRun,
  }) async {
    if (!mounted) return;

    if (!dryRun) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sync User CreatedAt'),
          content: const Text(
            'This will overwrite user.createdAt fields in Firestore with '
            'creation timestamps from Firebase Authentication. This action cannot be undone. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sync'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(dryRun
            ? 'Previewing sync of user createdAt...'
            : 'Syncing user createdAt from Auth...'),
      ),
    );

    try {
      final result = await service.syncUserCreatedAtFromAuth(dryRun: dryRun);
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final totalProcessed = result['totalProcessed'] ?? 0;
        final totalUpdated = result['totalUpdated'] ?? 0;
        final totalSkipped = result['totalSkipped'] ?? 0;
        final totalErrors = result['totalErrors'] ?? 0;

        // Show changes dialog for dry run
        if (dryRun && result['changes'] != null) {
          final changes = result['changes'] as List<dynamic>;
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Preview: Changes to be Made'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 600),
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Would update $totalUpdated of $totalProcessed users '
                        '($totalSkipped skipped, $totalErrors errors)',
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: changes.length,
                          itemBuilder: (context, index) {
                          final change = changes[index] as Map<String, dynamic>;
                          final from = change['from'] as String?;
                          final to = change['to'] as String?;
                          final email = change['email'] as String? ?? 'N/A';
                          final displayName = change['displayName'] as String?;
                          final uid = change['uid'] as String? ?? 'Unknown';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName != null && displayName.isNotEmpty
                                        ? '$displayName ($email)'
                                        : email,
                                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (from != null) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('From: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(
                                            _formatTimestamp(from),
                                            style: const TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ] else
                                    const Text('From: (not set)', style: TextStyle(fontStyle: FontStyle.italic)),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('To:   ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          _formatTimestamp(to ?? ''),
                                          style: const TextStyle(color: Colors.green),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'UID: $uid',
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dryRun
                  ? 'Preview: Would update $totalUpdated of $totalProcessed users '
                      '($totalSkipped skipped, $totalErrors errors)'
                  : 'Sync complete: Updated $totalUpdated of $totalProcessed users '
                      '($totalSkipped skipped, $totalErrors errors)',
            ),
            backgroundColor: totalErrors > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Show detailed results if there were errors
        if (totalErrors > 0 && result['errors'] != null) {
          if (!mounted) return;
          final errors = result['errors'] as List<dynamic>;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sync Errors'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    final error = errors[index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(error['email'] ?? error['uid'] ?? 'Unknown'),
                      subtitle: Text(error['error'] ?? 'Unknown error'),
                      dense: true,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg = service.syncCreatedAtError ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyGoogleAvatars(
    BuildContext context,
    UserManagementService service, {
    required bool dryRun,
  }) async {
    if (!mounted) return;

    if (!dryRun) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Copy Google Avatars to Storage'),
          content: const Text(
            'This will copy profile pictures from Google to Firebase Storage for '
            'users who still have Google avatar URLs. Each copy is rate-limited '
            '(~2.5s apart) to avoid hitting Google\'s limits. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(dryRun
            ? 'Previewing Google avatars to copy...'
            : 'Copying Google avatars to Storage (this may take a while)...'),
      ),
    );

    try {
      final result = await service.copyGoogleAvatarsToStorage(dryRun: dryRun);
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final totalProcessed = result['totalProcessed'] ?? 0;
        final totalCopied = result['totalCopied'] ?? 0;
        final totalUpdated = result['totalUpdated'] ?? 0;
        final totalSkipped = result['totalSkipped'] ?? 0;
        final totalErrors = result['totalErrors'] ?? 0;

        if (dryRun && result['changes'] != null) {
          final changes = result['changes'] as List<dynamic>;
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Preview: Users to Copy'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Would copy $totalCopied of $totalProcessed users '
                        '($totalSkipped skipped, $totalErrors errors)',
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      ...changes.take(20).map((c) {
                        final change = c as Map<String, dynamic>;
                        final email = change['email'] as String? ?? 'N/A';
                        final displayName =
                            change['displayName'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            displayName != null && displayName.isNotEmpty
                                ? '$displayName ($email)'
                                : email,
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                        );
                      }),
                      if (changes.length > 20)
                        Text(
                          '... and ${changes.length - 20} more',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dryRun
                  ? 'Preview: Would copy $totalCopied of $totalProcessed users '
                      '($totalSkipped skipped, $totalErrors errors)'
                  : 'Copy complete: Copied $totalCopied, updated $totalUpdated of $totalProcessed '
                      '($totalSkipped skipped, $totalErrors errors)',
            ),
            backgroundColor: totalErrors > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        if (totalErrors > 0 && result['errors'] != null) {
          if (!mounted) return;
          final errors = result['errors'] as List<dynamic>;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Copy Errors'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    final error = errors[index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(error['email'] ?? error['uid'] ?? 'Unknown'),
                      subtitle: Text(error['error'] ?? 'Unknown error'),
                      dense: true,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg =
            service.copyGoogleAvatarsError ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copy failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _makeProfilePicturesPublic(
    BuildContext context,
    UserManagementService service,
  ) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Making profile pictures public...'),
      ),
    );

    try {
      final result = await service.makeProfilePicturesPublic();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final totalProcessed = result['totalProcessed'] ?? 0;
        final totalMadePublic = result['totalMadePublic'] ?? 0;
        final totalSkipped = result['totalSkipped'] ?? 0;
        final totalErrors = result['totalErrors'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Done: Made $totalMadePublic public of $totalProcessed users '
              '($totalSkipped skipped, $totalErrors errors)',
            ),
            backgroundColor: totalErrors > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        if (totalErrors > 0 && result['errors'] != null) {
          if (!mounted) return;
          final errors = result['errors'] as List<dynamic>;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Errors'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    final error = errors[index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(error['email'] ?? error['uid'] ?? 'Unknown'),
                      subtitle: Text(error['error'] ?? 'Unknown error'),
                      dense: true,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg =
            service.makeProfilePicturesPublicError ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncSpotDisplayNames(
    BuildContext context,
    UserManagementService service, {
    required bool dryRun,
  }) async {
    if (!mounted) return;

    if (!dryRun) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sync Spot Display Names'),
          content: const Text(
            'This will update createdByName and contributors in the spots table '
            'to match each user\'s current display name from the users table. '
            'Only spots where the stored name does not match will be updated.\n\n'
            'Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sync'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(dryRun
            ? 'Previewing spot display name sync...'
            : 'Syncing spot display names (this may take a while)...'),
      ),
    );

    try {
      final result = await service.syncSpotDisplayNames(dryRun: dryRun);
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final totalUsersProcessed = result['totalUsersProcessed'] ?? 0;
        final spotsUpdated = result['spotsUpdated'] ?? 0;
        final spotsSkipped = result['spotsSkipped'] ?? 0;
        final totalErrors = result['totalErrors'] ?? 0;

        if (dryRun && result['changes'] != null) {
          final changes = result['changes'] as List<dynamic>;
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Preview: Spot Display Name Changes'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Would update $spotsUpdated spots across $totalUsersProcessed users '
                        '($spotsSkipped spots already match)',
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      ...changes.take(30).map((c) {
                        final change = c as Map<String, dynamic>;
                        final spotName = change['spotName'] as String? ?? '?';
                        final field = change['field'] as String? ?? '?';
                        final from = change['from'] as String? ?? '(empty)';
                        final to = change['to'] as String? ?? '(empty)';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '$spotName ($field): $from → $to',
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                        );
                      }),
                      if (changes.length > 30)
                        Text(
                          '... and ${changes.length - 30} more',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dryRun
                  ? 'Preview: Would update $spotsUpdated spots '
                      '($spotsSkipped already match)'
                  : 'Sync complete: Updated $spotsUpdated spots '
                      '($spotsSkipped already matched)',
            ),
            backgroundColor: totalErrors > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        if (totalErrors > 0 && result['errors'] != null) {
          if (!mounted) return;
          final errors = result['errors'] as List<dynamic>;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sync Errors'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    final error = errors[index] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(error['email'] ?? error['uid'] ?? 'Unknown'),
                      subtitle: Text(error['error'] ?? 'Unknown error'),
                      dense: true,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        final errorMsg =
            service.syncSpotDisplayNamesError ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.radius = 20});

  final app_user.User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = user.photoURL;
    final String? displayName = user.displayName;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    final String initials = _computeInitials(displayName ?? user.email);
    return CircleAvatar(
      radius: radius,
      child: Text(initials.toUpperCase()),
    );
  }

  String _computeInitials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final segment = parts.first;
      if (segment.length >= 2) {
        return segment.substring(0, 2);
      }
      return segment.isNotEmpty ? segment : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = '$first$last';
    return initials.trim().isNotEmpty ? initials : value.substring(0, 1);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FeatureAccessSection extends StatefulWidget {
  const _FeatureAccessSection({
    required this.user,
    required this.userService,
    required this.updatingFeatureAccess,
    required this.rootContext,
  });

  final app_user.User user;
  final UserManagementService userService;
  final bool updatingFeatureAccess;
  final BuildContext rootContext;

  @override
  State<_FeatureAccessSection> createState() => _FeatureAccessSectionState();
}

class _FeatureAccessSectionState extends State<_FeatureAccessSection> {
  final TextEditingController _newFeatureController = TextEditingController();
  final Map<String, bool> _localFeatureAccess = {};

  @override
  void initState() {
    super.initState();
    _syncLocalFeatureAccess();
  }

  @override
  void didUpdateWidget(_FeatureAccessSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        !_mapsEqual(oldWidget.user.featureAccess, widget.user.featureAccess)) {
      _syncLocalFeatureAccess();
    }
  }

  bool _mapsEqual(Map<String, bool>? a, Map<String, bool>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _syncLocalFeatureAccess() {
    _localFeatureAccess.clear();
    if (widget.user.featureAccess != null) {
      _localFeatureAccess.addAll(widget.user.featureAccess!);
    }
  }

  @override
  void dispose() {
    _newFeatureController.dispose();
    super.dispose();
  }

  Future<void> _updateFeatureAccess(String featureName, bool hasAccess) async {
    final bool success = await widget.userService.updateFeatureAccess(
      widget.user.id,
      featureName,
      hasAccess,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _localFeatureAccess[featureName] = hasAccess;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        SnackBar(
          content: Text(hasAccess
              ? 'Access granted to "$featureName"'
              : 'Access removed from "$featureName"'),
          backgroundColor: hasAccess ? Colors.green : Colors.orange,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(
          content: Text('Failed to update feature access'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeFeatureAccess(String featureName) async {
    final bool success = await widget.userService.updateFeatureAccess(
      widget.user.id,
      featureName,
      false,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _localFeatureAccess.remove(featureName);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        SnackBar(
          content: Text('Removed "$featureName" access'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove feature access'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addFeatureAccess() async {
    final featureName = _newFeatureController.text.trim();
    if (featureName.isEmpty) {
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(
          content: Text('Please enter a feature name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_localFeatureAccess.containsKey(featureName)) {
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(
          content: Text('Feature already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool success = await widget.userService.updateFeatureAccess(
      widget.user.id,
      featureName,
      true,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _localFeatureAccess[featureName] = true;
      });
      _newFeatureController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        SnackBar(
          content: Text('Added "$featureName" access'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(
          content: Text('Failed to add feature access'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.updatingFeatureAccess) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_localFeatureAccess.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No feature access configured',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          )
        else
          ..._localFeatureAccess.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                child: ListTile(
                  title: Text(entry.key),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: entry.value,
                        onChanged: widget.updatingFeatureAccess
                            ? null
                            : (value) => _updateFeatureAccess(entry.key, value),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove feature access',
                        onPressed: widget.updatingFeatureAccess
                            ? null
                            : () => _removeFeatureAccess(entry.key),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newFeatureController,
                decoration: const InputDecoration(
                  labelText: 'Feature name',
                  hintText: 'e.g., spotLists',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !widget.updatingFeatureAccess,
                onSubmitted: (_) => _addFeatureAccess(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add feature access',
              onPressed: widget.updatingFeatureAccess ? null : _addFeatureAccess,
            ),
          ],
        ),
      ],
    );
  }
}
