import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/page_scaffold.dart';
import 'admin_tool_widgets.dart';
import 'spot_data_actions.dart';

class SpotImagesScreen extends StatelessWidget {
  const SpotImagesScreen({super.key});

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
        title: 'Spot images',
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Administrator access required')),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    return PageScaffold(
      title: 'Spot images',
      onBack: () => _handleBack(context),
      scrollable: false,
      body: ListView(
        children: [
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.image_search,
                title: 'Duplicate image URLs',
                subtitle:
                    'Find all spots with duplicate image URLs in their image array',
                onTap: () => context.push('/admin/duplicate-images'),
              ),
              AdminToolTile(
                icon: Icons.image_not_supported,
                title: 'Missing resized images',
                subtitle:
                    'Find spot images that do not have a resized version available',
                onTap: () => context.push('/admin/missing-resized-images'),
              ),
              AdminToolTile(
                icon: Icons.cleaning_services,
                title: 'Cleanup unused images',
                subtitle:
                    'Move unreferenced spot images (and resized versions) to trash',
                showChevron: false,
                onTap: () => SpotDataActions.cleanupUnusedImages(context),
              ),
              AdminToolTile(
                icon: Icons.broken_image,
                title: 'Find missing images',
                subtitle:
                    'Find image files referenced by spots that are missing in storage',
                showChevron: false,
                onTap: () => SpotDataActions.findMissingImages(context),
              ),
              AdminToolTile(
                icon: Icons.photo_library_outlined,
                title: 'Backfill spot image flags',
                subtitle:
                    'Set hasImages from imageUrls for every existing spot',
                showChevron: false,
                onTap: () => SpotDataActions.backfillSpotHasImages(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
