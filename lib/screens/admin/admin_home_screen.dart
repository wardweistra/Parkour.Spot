import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';

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
            Card(
              child: ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync Sources'),
                subtitle: const Text('Add, edit, delete, and sync external sources'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/sources'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('User Management'),
                subtitle: const Text('Review users, stats, and moderator access'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/users'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('User Activity Metrics'),
                subtitle: const Text('Calculate and sync DAU/WAU/MAU metrics to Google Sheets'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/user-activity-metrics'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Geocode Missing Addresses'),
                subtitle: const Text('Fill address, city, country for spots with empty fields'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/geocoding'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Spot Management'),
                subtitle: const Text('Search and delete spots by source and last updated date'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/spot-management'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('URBN Migration'),
                subtitle: const Text('Import spots from URBN Jumpers JSON file'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/urbn-migration'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit Log Viewer'),
                subtitle: const Text('View spot creations, user creations, and audit log actions'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/audit-log'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.image_search),
                title: const Text('Duplicate Image URLs'),
                subtitle: const Text('Find all spots with duplicate image URLs in their image array'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/duplicate-images'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Device Detection Info'),
                subtitle: const Text('View device detection and PWA install service status'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/device-detection'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_rate),
                title: const Text('Recompute Ratings for Rated Spots'),
                subtitle: const Text('Recalculate average, count, and Wilson lower bound from ratings'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Recompute Ratings'),
                      content: const Text('This will recompute rating aggregates for all spots that have ratings. Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Run'),
                        ),
                      ],
                    ),
                  );

                if (confirmed != true) return;

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recomputing ratings...')),
                );

                try {
                  final spotService = Provider.of<SpotService>(context, listen: false);
                  final result = await spotService.recomputeAllRatedSpots();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Done. Processed ${result['processed']}, updated ${result['updated']}, failed ${result['failed']}')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.signal_cellular_alt),
                title: const Text('Recompute Spot Rankings'),
                subtitle: const Text('Recalculate ranking field for all spots based on ratings'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Recompute Spot Rankings'),
                      content: const Text('This will recalculate the ranking field for all spots based on their ratings and the average Wilson score. This is useful after changing the Wilson score threshold in settings. Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Run'),
                        ),
                      ],
                    ),
                  );

                if (confirmed != true) return;

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recomputing spot rankings...')),
                );

                try {
                  final spotService = Provider.of<SpotService>(context, listen: false);
                  final result = await spotService.recomputeSpotRankings();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Done. Processed ${result['processed']}, updated ${result['updated']}, failed ${result['failed']}')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.filter_alt),
                title: const Text('Backfill Spot Normalized Filters'),
                subtitle: const Text('Generate normalizedFilterFields for all existing spots'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Backfill Spot Normalized Filters'),
                      content: const Text(
                        'This will compute normalizedFilterFields for every spot document. Continue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Run'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true) return;

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backfilling normalized spot filters...')),
                  );

                  try {
                    final spotService = Provider.of<SpotService>(context, listen: false);
                    final result = await spotService.backfillSpotNormalizedFilterFields();
                    if (!context.mounted) return;

                    if (result['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Done. Processed ${result['processed']}, updated ${result['updated']}, unchanged ${result['unchanged']}, failed ${result['failed']}',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${result['error'] ?? 'Unknown error'}')),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      );
  }

}

