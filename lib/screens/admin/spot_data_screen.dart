import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/jumpflix_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';
import 'admin_tool_widgets.dart';
import 'spot_data_actions.dart';

class SpotDataScreen extends StatelessWidget {
  const SpotDataScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return PageScaffold(
        title: 'Spot data',
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Administrator access required')),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    return PageScaffold(
      title: 'Spot data',
      onBack: () => _handleBack(context),
      scrollable: false,
      body: ListView(
        children: [
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.place,
                title: 'Geocode missing addresses',
                subtitle:
                    'Fill address, city, country for spots with empty fields',
                onTap: () => context.push('/admin/geocoding'),
              ),
              AdminToolTile(
                icon: Icons.search,
                title: 'Backfill spot name search',
                subtitle: 'Populate spotSearchTerms for Explore autocomplete',
                showChevron: false,
                onTap: () => SpotDataActions.backfillSpotNameSearch(context),
              ),
              AdminToolTile(
                icon: Icons.star_rate,
                title: 'Recompute ratings for rated spots',
                subtitle:
                    'Recalculate average, count, and Wilson lower bound from ratings',
                showChevron: false,
                onTap: () => _recomputeRatings(context),
              ),
              AdminToolTile(
                icon: Icons.signal_cellular_alt,
                title: 'Recompute spot rankings',
                subtitle:
                    'Recalculate ranking field for all spots based on ratings',
                showChevron: false,
                onTap: () => _recomputeSpotRankings(context),
              ),
              AdminToolTile(
                icon: Icons.video_library,
                title: 'Import Jumpflix spot links',
                subtitle:
                    'Fetch Jumpflix video-spot mappings and update the database (also runs nightly at 02:00 UTC)',
                showChevron: false,
                onTap: () => _importJumpflixSpotLinks(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmAction({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<void> _recomputeRatings(BuildContext context) async {
  final confirmed = await _confirmAction(
    context: context,
    title: 'Recompute ratings',
    content:
        'This will recompute rating aggregates for all spots that have ratings. Continue?',
    confirmLabel: 'Run',
  );
  if (!confirmed || !context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Recomputing ratings...')));

  try {
    final spotService = Provider.of<SpotService>(context, listen: false);
    final result = await spotService.recomputeAllRatedSpots();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Done. Processed ${result['processed']}, updated ${result['updated']}, failed ${result['failed']}',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _recomputeSpotRankings(BuildContext context) async {
  final confirmed = await _confirmAction(
    context: context,
    title: 'Recompute spot rankings',
    content:
        'This will recalculate the ranking field for all spots based on their ratings and the average Wilson score. This is useful after changing the Wilson score threshold in settings. Continue?',
    confirmLabel: 'Run',
  );
  if (!confirmed || !context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Recomputing spot rankings...')));

  try {
    final spotService = Provider.of<SpotService>(context, listen: false);
    final result = await spotService.recomputeSpotRankings();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Done. Processed ${result['processed']}, updated ${result['updated']}, failed ${result['failed']}',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _importJumpflixSpotLinks(BuildContext context) async {
  final confirmed = await _confirmAction(
    context: context,
    title: 'Import Jumpflix spot links',
    content:
        'This will fetch video-spot mappings from Jumpflix and update the '
        'spotJumpflixVideos collection. Continue?',
    confirmLabel: 'Import',
  );
  if (!confirmed || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Importing Jumpflix spot links...')),
  );

  try {
    final jumpflixService = Provider.of<JumpflixService>(
      context,
      listen: false,
    );
    final result = await jumpflixService.runJumpflixImport();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Done. Spots updated: ${result['spotsUpdated']}, '
          'removed: ${result['spotsRemoved']}, '
          'Jumpflix videos: ${result['jumpflixVideoCount']}',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
