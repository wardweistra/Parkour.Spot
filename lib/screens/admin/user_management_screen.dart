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
          onPressed: () => context.go('/admin'),
        ),
        actions: [
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

                final List<app_user.User> filteredUsers = _searchTerm.isEmpty
                    ? service.users
                    : service.users.where((user) {
                        final name = user.displayName?.toLowerCase() ?? '';
                        final email = user.email.toLowerCase();
                        return name.contains(_searchTerm) || email.contains(_searchTerm);
                      }).toList();

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
                      return Card(
                        child: ListTile(
                          leading: _UserAvatar(user: user),
                          title: Text(user.displayName?.isNotEmpty == true ? user.displayName! : user.email),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              if (user.createdAt != null)
                                Text(
                                  'Joined: ${_formatDate(user.createdAt!)}',
                                  style: Theme.of(context).textTheme.bodySmall,
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
                                Text(
                                  user.displayName?.isNotEmpty == true ? user.displayName! : user.email,
                                  style: Theme.of(sheetContext).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(user.email),
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
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(
                                      content: Text(value
                                          ? 'Moderator access granted to ${user.displayName ?? user.email}'
                                          : 'Moderator access removed from ${user.displayName ?? user.email}'),
                                      backgroundColor: value ? Colors.green : Colors.orange,
                                    ),
                                  );
                                } else {
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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
