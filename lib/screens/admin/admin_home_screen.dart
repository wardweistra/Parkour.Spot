import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';
import 'admin_tool_widgets.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return PageScaffold(
        title: 'Admin',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 12),
              const Text('Administrator access required'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/explore?tab=profile'),
                child: const Text('Back to Profile'),
              ),
            ],
          ),
        ),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    return PageScaffold(
      title: 'Admin Tools',
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/explore?tab=profile');
        }
      },
      scrollable: false,
      body: ListView(
        children: [
          const AdminSectionHeader(title: 'Spots'),
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.sync,
                title: 'Sync Sources',
                subtitle: 'Add, edit, delete, and sync external sources',
                onTap: () => context.push('/admin/sources'),
              ),
              AdminToolTile(
                icon: Icons.delete_sweep,
                title: 'Spot Management',
                subtitle:
                    'Search and delete spots by source and last updated date',
                onTap: () => context.push('/admin/spot-management'),
              ),
              AdminToolTile(
                icon: Icons.image_outlined,
                title: 'Spot data and images',
                subtitle:
                    'Geocode, image cleanup, ratings, rankings, and Jumpflix links',
                onTap: () => context.push('/admin/spot-data'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Events'),
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.event_repeat_outlined,
                title: 'Event Sync Sources',
                subtitle: 'Configure and sync external calendar sources',
                onTap: () => context.push('/admin/event-sources'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Users'),
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.people_outline,
                title: 'User Management',
                subtitle: 'Review users, stats, and moderator access',
                onTap: () => context.push('/admin/users'),
              ),
              AdminToolTile(
                icon: Icons.notifications_outlined,
                title: 'All notifications',
                subtitle:
                    'Browse every in-app notification across users (newest first)',
                onTap: () => context.push('/admin/notifications'),
              ),
              AdminToolTile(
                icon: Icons.phonelink_ring_outlined,
                title: 'Web push subscriptions',
                subtitle:
                    'Pick a user, select devices, send a push notification',
                onTap: () => context.push('/admin/push-subscriptions'),
              ),
              AdminToolTile(
                icon: Icons.analytics,
                title: 'User Activity Metrics',
                subtitle:
                    'Calculate and sync DAU/WAU/MAU metrics, Spots, Users, and Events to Google Sheets',
                onTap: () => context.push('/admin/user-activity-metrics'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Site'),
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.api,
                title: 'API Clients',
                subtitle: 'Register clients and track Spot Details API usage',
                onTap: () => context.push('/admin/api-clients'),
              ),
              AdminToolTile(
                icon: Icons.history,
                title: 'Audit Log Viewer',
                subtitle:
                    'View spot creations, user creations, and audit log actions',
                onTap: () => context.push('/admin/audit-log'),
              ),
              AdminToolTile(
                icon: Icons.map,
                title: 'Generate Sitemaps',
                subtitle:
                    'Regenerate XML sitemaps for search engines (spots, lists, users)',
                showChevron: false,
                onTap: () => _generateSitemaps(context),
              ),
              AdminToolTile(
                icon: Icons.phone_android,
                title: 'Device Detection Info',
                subtitle:
                    'View device detection and PWA install service status',
                onTap: () => context.push('/admin/device-detection'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _generateSitemaps(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Generate Sitemaps'),
      content: const Text(
        'This will regenerate all sitemaps (country pages, unlocated spots, '
        'public lists, user profiles) and upload them to Storage. '
        'This may take a few minutes. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Generate'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Generating sitemaps...')));

  try {
    final spotService = Provider.of<SpotService>(context, listen: false);
    await spotService.generateSitemaps();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sitemaps generated successfully')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
