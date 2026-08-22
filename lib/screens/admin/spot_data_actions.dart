import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sync_source_service.dart';
import '../../utils/search_index_backfill_message.dart';
import 'missing_images_screen.dart';

/// JSON/callable counts often decode as [double] on web — avoid showing `13893.0`.
String _formatStatInt(dynamic v) {
  final n = v as num?;
  if (n == null) return '';
  return n.toInt().toString();
}

/// Spot image and search-index maintenance, shown from Spot data / Spot images.
class SpotDataActions {
  SpotDataActions._();

  static Future<void> cleanupUnusedImages(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cleanup unused images'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will move all unused images (including resized versions) to /spots/trash folder.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('The function will:', style: TextStyle(fontSize: 12)),
            SizedBox(height: 4),
            Text(
              '• List all files in /spots folder (including /spots/resized)',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '• List all image files referenced by spots',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '• Move unreferenced images and resized versions to /spots/trash',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              'This is safe - images are moved, not deleted. You can restore them from trash if needed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Cleaning up unused images...'),
          ],
        ),
      ),
    );

    try {
      final syncService = context.read<SyncSourceService>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final cleanupResult = await syncService.cleanupUnusedImages();

      if (!context.mounted) return;
      navigator.pop();

      if (cleanupResult != null && cleanupResult['success'] == true) {
        final movedCount = cleanupResult['movedCount'] ?? 0;
        final skippedCount = cleanupResult['skippedCount'] ?? 0;
        final totalFiles = cleanupResult['totalFiles'] ?? 0;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Cleanup completed: $movedCount images moved to trash, $skippedCount skipped (out of $totalFiles total)',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Cleanup failed: ${cleanupResult?['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> findMissingImages(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking for missing images...'),
          ],
        ),
      ),
    );

    try {
      final syncService = context.read<SyncSourceService>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final result = await syncService.findMissingImages();

      if (!context.mounted) return;
      navigator.pop();

      if (result != null && result['success'] == true) {
        final missingImages = result['missingImages'] as List<dynamic>? ?? [];
        final totalReferenced = result['totalReferencedImages'] ?? 0;
        final totalExisting = result['totalExistingFiles'] ?? 0;
        final missingCount = result['missingImagesCount'] ?? 0;

        if (missingCount == 0) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No missing images found! All referenced images exist.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => MissingImagesScreen(
                missingImages: missingImages,
                totalReferenced: (totalReferenced as num).toInt(),
                totalExisting: (totalExisting as num).toInt(),
              ),
            ),
          );
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to check missing images: ${result?['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check missing images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> backfillSpotNameSearch(BuildContext context) async {
    var purgeTerms = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Backfill spot name search'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Populates spotSearchTerms for visible spots (Explore autocomplete). '
                'This may take a few minutes for large databases.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: purgeTerms,
                onChanged: (v) => setState(() => purgeTerms = v ?? false),
                title: const Text('Purge existing terms first'),
                subtitle: const Text(
                  'Deletes all spotSearchTerms, then rebuilds only for spots '
                  'shown on the map (not hidden or duplicates).',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !context.mounted) return;

    final syncService = context.read<SyncSourceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    late NavigatorState navigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        navigator = Navigator.of(c);
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Backfilling spotSearchTerms...'),
            ],
          ),
        );
      },
    );
    try {
      final result = await syncService.backfillSpotNameLower(purge: purgeTerms);
      navigator.pop();
      if (!context.mounted) return;
      if (result != null && result['success'] == true) {
        final stats = result['stats'] as Map<String, dynamic>?;
        final msg = stats != null
            ? formatSearchIndexBackfillMessage(
                entityLabel: 'Spots',
                totalProcessed: stats['totalProcessed'],
                searchTermsWritten: stats['searchTermsWritten'],
                searchTermsDeleted: stats['searchTermsDeleted'],
                purged: stats['purged'] == true,
              )
            : 'Backfill completed';
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(syncService.error ?? 'Backfill failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      navigator.pop();
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Backfill failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> backfillSpotHasImages(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Backfill spot image flags'),
        content: const Text(
          'Sets hasImages from imageUrls for every existing spot. '
          'The operation is safe to run again and only updates stale values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final syncService = context.read<SyncSourceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    late NavigatorState navigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        navigator = Navigator.of(c);
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Backfilling spot image flags...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await syncService.backfillSpotHasImages();
      navigator.pop();
      if (!context.mounted) return;

      if (result != null && result['success'] == true) {
        final statsValue = result['stats'];
        final stats = statsValue is Map
            ? Map<String, dynamic>.from(statsValue)
            : null;
        final message = stats == null
            ? 'Backfill completed'
            : 'Backfill completed. Processed: '
                  '${_formatStatInt(stats['totalProcessed'])}, updated: '
                  '${_formatStatInt(stats['totalUpdated'])}, with images: '
                  '${_formatStatInt(stats['spotsWithImages'])}.';
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(syncService.error ?? 'Backfill failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      navigator.pop();
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Backfill failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
