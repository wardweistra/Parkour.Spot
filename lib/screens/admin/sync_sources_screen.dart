import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/sync_source_service.dart';

class SyncSourcesScreen extends StatefulWidget {
  const SyncSourcesScreen({super.key});

  @override
  State<SyncSourcesScreen> createState() => _SyncSourcesScreenState();
}

class _SyncSourcesScreenState extends State<SyncSourcesScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the fetch call until after the build phase is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<SyncSourceService>();
      if (service.sources.isEmpty && !service.isLoading) {
        service.fetchSyncSources(includeInactive: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sync Sources')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Sources'),
        actions: [
          Consumer<SyncSourceService>(
            builder: (context, service, child) {
              return IconButton(
                icon: service.isSyncingAll 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync All',
                onPressed: service.isSyncingAll ? null : () async {
                  if (!mounted) return;
                  final syncService = context.read<SyncSourceService>();
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await syncService.syncAllSources();
                  if (!mounted) return;
                  if (result != null) {
                    final stats = result['totalStats'] as Map<String, dynamic>?;
                    final message = stats != null 
                        ? 'Sync completed! Created: ${stats['created']}, Updated: ${stats['updated']}, Geocoded: ${stats['geocoded']}'
                        : 'Sync completed successfully';
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(syncService.error ?? 'Sync failed'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Cleanup Unused Images',
            onPressed: () => _showCleanupDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.broken_image),
            tooltip: 'Find Missing Images',
            onPressed: () => _showMissingImagesDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Find Orphaned Spots',
            onPressed: () => _showOrphanedSpotsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.update),
            tooltip: 'Update Spot Source Names',
            onPressed: () => _showUpdateSourceNamesDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Source',
            onPressed: () => _openEditDialog(context),
          ),
        ],
      ),
      body: Consumer<SyncSourceService>(
        builder: (context, service, _) {
          if (service.isLoading && service.sources.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.error != null && service.sources.isEmpty) {
            return Center(child: Text(service.error!));
          }
          final sources = service.sources..sort((a, b) => a.name.compareTo(b.name));
          return Stack(
            children: [
              ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = sources[index];
              return Card(
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.kmzUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (s.description != null && s.description!.isNotEmpty)
                        Text(s.description!),
                      Row(
                        children: [
                          Chip(label: Text(s.isActive ? 'Active' : 'Inactive')),
                          if (s.lastSyncAt != null) ...[
                            const SizedBox(width: 8),
                            Chip(label: Text('Last sync: ${s.lastSyncAt}')),
                          ],
                        ],
                      ),
                      if (s.allFolders != null && s.allFolders!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('Folders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ...s.allFolders!.map((folder) => Chip(
                              label: Text(folder, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.blue.shade100,
                            )),
                          ],
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.isActive)
                        Consumer<SyncSourceService>(
                          builder: (context, service, child) {
                            final isThisSourceSyncing = service.syncingSources.contains(s.id);
                            return IconButton(
                              icon: isThisSourceSyncing 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync),
                              tooltip: 'Sync this source',
                              onPressed: isThisSourceSyncing ? null : () async {
                                if (!mounted) return;
                                final syncService = context.read<SyncSourceService>();
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final result = await syncService.syncSingleSource(s.id);
                                if (!mounted) return;
                                if (result != null) {
                                  final stats = result['stats'] as Map<String, dynamic>?;
                                  final message = stats != null 
                                      ? '${s.name} sync completed! Created: ${stats['created']}, Updated: ${stats['updated']}, Geocoded: ${stats['geocoded']}'
                                      : '${s.name} sync completed successfully';
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(syncService.error ?? 'Sync failed for ${s.name}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          final syncService = context.read<SyncSourceService>();
                          switch (v) {
                            case 'edit':
                              _openEditDialog(context, source: s);
                              break;
                            case 'toggleActive':
                              await syncService.updateSource(
                                sourceId: s.id,
                                isActive: !s.isActive,
                              );
                              break;
                            case 'delete':
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete Source'),
                                  content: Text('Delete \'${s.name}\'?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await syncService.deleteSource(s.id);
                              }
                              break;
                          }
                        },
                        itemBuilder: (c) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'toggleActive', child: Text(s.isActive ? 'Deactivate' : 'Activate')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
              // Loading overlay when syncing all sources
              if (service.isSyncingAll && service.sources.isNotEmpty)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Syncing all sources...', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context, {SyncSource? source}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => SyncSourceEditDialog(source: source),
    );

    if (saved == true && mounted) {
      final syncService = context.read<SyncSourceService>();
      await syncService.fetchSyncSources(includeInactive: true);
    }
  }

  Future<void> _showCleanupDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cleanup Unused Images'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will move all unused images (including resized versions) to /spots/trash folder.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'The function will:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• List all files in /spots folder (including /spots/resized)', style: TextStyle(fontSize: 12)),
            Text('• List all image files referenced by spots', style: TextStyle(fontSize: 12)),
            Text('• Move unreferenced images and resized versions to /spots/trash', style: TextStyle(fontSize: 12)),
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

    if (confirmed == true) {
      // Show loading indicator
      showDialog(
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
        if (!mounted) return;
        final syncService = context.read<SyncSourceService>();
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final cleanupResult = await syncService.cleanupUnusedImages();
        
        if (!mounted) return;
        navigator.pop(); // Close loading dialog
        
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
        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleanup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showMissingImagesDialog(BuildContext context) async {
    // Show loading indicator
    showDialog(
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
      if (!mounted) return;
      final syncService = context.read<SyncSourceService>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final result = await syncService.findMissingImages();
      
      if (!mounted) return;
      navigator.pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
        final missingImages = result['missingImages'] as List<dynamic>? ?? [];
        final totalReferenced = result['totalReferencedImages'] ?? 0;
        final totalExisting = result['totalExistingFiles'] ?? 0;
        final missingCount = result['missingImagesCount'] ?? 0;
        
        if (missingCount == 0) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('No missing images found! All referenced images exist.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Navigate to missing images screen
          navigator.push(
            MaterialPageRoute(
              builder: (context) => MissingImagesScreen(
                missingImages: missingImages,
                totalReferenced: totalReferenced,
                totalExisting: totalExisting,
              ),
            ),
          );
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to check missing images: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check missing images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showOrphanedSpotsDialog(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking for orphaned spots...'),
          ],
        ),
      ),
    );

    try {
      if (!mounted) return;
      final syncService = context.read<SyncSourceService>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final result = await syncService.findOrphanedSpots();
      
      if (!mounted) return;
      navigator.pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
          final orphanedSpots = result['orphanedSpots'] as List<dynamic>? ?? [];
          final totalSpotsWithSource = result['totalSpotsWithSource'] ?? 0;
          final orphanedCount = result['orphanedSpotsCount'] ?? 0;
          
          if (orphanedCount == 0) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('No orphaned spots found! All spots have valid sources.'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Show detailed dialog with orphaned spots
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Orphaned Spots Found'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Found $orphanedCount orphaned spots out of $totalSpotsWithSource spots with spotSource field.'),
                      const SizedBox(height: 16),
                      const Text('Orphaned spots:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: orphanedSpots.length,
                          itemBuilder: (context, index) {
                            final spot = orphanedSpots[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                spot['spotName'] ?? 'Unnamed Spot',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text('ID: ${spot['spotId']}'),
                                              Text('Source: ${spot['spotSource']}'),
                                              if (spot['address'] != null) Text('Address: ${spot['address']}'),
                                              if (spot['city'] != null) Text('City: ${spot['city']}'),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Delete Spot',
                                          onPressed: () => _confirmDeleteSpot(context, spot),
                                        ),
                                      ],
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
                actions: [
                  if (orphanedCount > 0)
                    TextButton(
                      onPressed: () => _confirmDeleteAllSpots(context, orphanedSpots),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete All'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to check orphaned spots: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check orphaned spots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSpot(BuildContext context, Map<String, dynamic> spot) async {
    final spotName = spot['spotName'] ?? 'Unnamed Spot';
    final spotId = spot['spotId'];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spot'),
        content: Text('Are you sure you want to delete "$spotName"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteSpot(context, spotId);
    }
  }

  Future<void> _deleteSpot(BuildContext context, String spotId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting spot...'),
            ],
          ),
        ),
      );

      // Delete the spot using cloud function
      if (!mounted) return;
      final syncService = context.read<SyncSourceService>();
      final result = await syncService.deleteSpot(spotId);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Spot deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the orphaned spots dialog
        if (!mounted) return;
        Navigator.of(context).pop(); // Close the orphaned spots dialog
        _showOrphanedSpotsDialog(context); // Reopen to show updated list
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete spot: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete spot: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAllSpots(BuildContext context, List<dynamic> orphanedSpots) async {
    final count = orphanedSpots.length;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Orphaned Spots'),
        content: Text('Are you sure you want to delete all $count orphaned spots?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteAllSpots(context, orphanedSpots);
    }
  }

  Future<void> _deleteAllSpots(BuildContext context, List<dynamic> orphanedSpots) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting all orphaned spots...'),
            ],
          ),
        ),
      );

      // Extract spot IDs
      final spotIds = orphanedSpots.map((spot) => spot['spotId'] as String).toList();

      // Delete all spots using cloud function
      if (!mounted) return;
      final syncService = context.read<SyncSourceService>();
      final result = await syncService.deleteSpots(spotIds);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Successfully deleted ${orphanedSpots.length} orphaned spots'),
            backgroundColor: Colors.green,
          ),
        );

        // Close the orphaned spots dialog
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete spots: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete spots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showUpdateSourceNamesDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Spot Source Names'),
          content: const Text(
            'This will update the cached source names for all spots. '
            'This is useful for spots created before the source name caching feature was added.\n\n'
            'Do you want to update all spots or select a specific source?'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('All Sources'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateSpotSourceNames(context, null);
              },
            ),
            TextButton(
              child: const Text('Select Source'),
              onPressed: () {
                Navigator.of(context).pop();
                _showSourceSelectionDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSourceSelectionDialog(BuildContext context) async {
    final syncService = context.read<SyncSourceService>();
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Source'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: syncService.sources.length,
              itemBuilder: (context, index) {
                final source = syncService.sources[index];
                return ListTile(
                  title: Text(source.name),
                  subtitle: Text(source.id),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _updateSpotSourceNames(context, source.id);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSpotSourceNames(BuildContext context, String? sourceId) async {
    final syncService = context.read<SyncSourceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Show loading dialog and store the navigator context
    late NavigatorState navigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        navigator = Navigator.of(dialogContext);
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating spot source names...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await syncService.updateSpotSourceNames(sourceId: sourceId);
      
      // Close loading dialog using the stored navigator
      navigator.pop();
      
      if (mounted) {
        if (result != null && result['success'] == true) {
          final stats = result['stats'] as Map<String, dynamic>?;
          final message = stats != null 
              ? 'Update completed! Total: ${stats['totalSpots']}, Updated: ${stats['updated']}, Skipped: ${stats['skipped']}'
              : 'Update completed successfully';
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(syncService.error ?? 'Update failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog using the stored navigator
      navigator.pop();
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class SyncSourceEditDialog extends StatefulWidget {
  final SyncSource? source;

  const SyncSourceEditDialog({super.key, this.source});

  @override
  State<SyncSourceEditDialog> createState() => _SyncSourceEditDialogState();
}

class _SyncSourceEditDialogState extends State<SyncSourceEditDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController urlCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController publicUrlCtrl;
  late final TextEditingController instagramHandleCtrl;
  late final TextEditingController includeFoldersCtrl;
  late bool isActive;
  late bool recordFolderName;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.source?.name ?? '');
    urlCtrl = TextEditingController(text: widget.source?.kmzUrl ?? '');
    descCtrl = TextEditingController(text: widget.source?.description ?? '');
    publicUrlCtrl = TextEditingController(text: widget.source?.publicUrl ?? '');
    instagramHandleCtrl = TextEditingController(text: widget.source?.instagramHandle ?? '');
    includeFoldersCtrl = TextEditingController(
      text: (widget.source?.includeFolders == null || widget.source?.includeFolders?.isEmpty == true)
          ? ''
          : widget.source!.includeFolders!.join('\n'),
    );
    isActive = widget.source?.isActive ?? true;
    recordFolderName = widget.source?.recordFolderName ?? false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    descCtrl.dispose();
    publicUrlCtrl.dispose();
    instagramHandleCtrl.dispose();
    includeFoldersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.source == null ? 'Add Source' : 'Edit Source'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Source URL (KMZ/KML/GeoJSON)',
                  helperText: 'Paste Google My Maps KMZ/KML or OpenStreetMap uMap GeoJSON URL',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              TextFormField(
                controller: publicUrlCtrl,
                decoration: const InputDecoration(labelText: 'Public URL (optional)'),
                keyboardType: TextInputType.url,
              ),
              TextFormField(
                controller: instagramHandleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram Handle (optional)',
                  helperText: 'Instagram username without @ symbol (e.g., parkour_spots)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: includeFoldersCtrl,
                decoration: const InputDecoration(
                  labelText: 'Include Folders (optional)',
                  helperText: 'One folder name per line. Folder names with commas are fully supported.',
                ),
                maxLines: 5,
                minLines: 3,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Record Folder/Layer on Spots'),
                subtitle: const Text('If enabled, store the KML folder name or uMap layer on each imported spot'),
                value: recordFolderName,
                onChanged: (v) => setState(() => recordFolderName = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final service = context.read<SyncSourceService>();
            bool ok;
            if (widget.source == null) {
              ok = await service.createSource(
                name: nameCtrl.text.trim(),
                kmzUrl: urlCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                publicUrl: publicUrlCtrl.text.trim().isEmpty ? null : publicUrlCtrl.text.trim(),
                instagramHandle: instagramHandleCtrl.text.trim().isEmpty ? null : instagramHandleCtrl.text.trim(),
                isActive: isActive,
                includeFolders: includeFoldersCtrl.text.trim().isEmpty
                    ? null
                    : includeFoldersCtrl.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                recordFolderName: recordFolderName,
              );
            } else {
              ok = await service.updateSource(
                sourceId: widget.source!.id,
                name: nameCtrl.text.trim(),
                kmzUrl: urlCtrl.text.trim(),
                description: descCtrl.text.trim(),
                publicUrl: publicUrlCtrl.text.trim(),
                instagramHandle: instagramHandleCtrl.text.trim(),
                isActive: isActive,
                includeFolders: includeFoldersCtrl.text.trim().isEmpty
                    ? <String>[]
                    : includeFoldersCtrl.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList(),
                recordFolderName: recordFolderName,
              );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Saved' : 'Failed to save')),
              );
            }
            Navigator.pop(context, ok);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class MissingImagesScreen extends StatefulWidget {
  final List<dynamic> missingImages;
  final int totalReferenced;
  final int totalExisting;

  const MissingImagesScreen({
    super.key,
    required this.missingImages,
    required this.totalReferenced,
    required this.totalExisting,
  });

  @override
  State<MissingImagesScreen> createState() => _MissingImagesScreenState();
}

class _MissingImagesScreenState extends State<MissingImagesScreen> {
  final Map<String, Uint8List?> _selectedImages = {};
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Missing Images (${widget.missingImages.length})'),
        actions: [
          if (_selectedImages.isNotEmpty)
            TextButton(
              onPressed: _isUploading ? null : _uploadSelectedImages,
              child: Text(_isUploading ? 'Uploading...' : 'Upload Selected'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missing Images Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Total referenced images: ${widget.totalReferenced}'),
                  Text('Total existing files: ${widget.totalExisting}'),
                  Text('Missing images: ${widget.missingImages.length}'),
                ],
              ),
            ),
          ),
          // Missing images list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.missingImages.length,
              itemBuilder: (context, index) {
                final missingImage = widget.missingImages[index];
                final filename = missingImage['filename'] as String;
                final spots = missingImage['spots'] as List<dynamic>;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(filename),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Referenced by ${spots.length} spot(s):'),
                        ...spots.map((spot) => Text(
                          '• ${spot['spotName']} (${spot['spotId']})',
                          style: const TextStyle(fontSize: 12),
                        )),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedImages.containsKey(filename))
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.upload),
                            onPressed: () => _selectImage(filename),
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
    );
  }

  Future<void> _selectImage(String filename) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImages[filename] = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadSelectedImages() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });

    int successCount = 0;
    int failCount = 0;

    final syncService = context.read<SyncSourceService>();
    for (final entry in _selectedImages.entries) {
      if (entry.value == null) continue;
      
      try {
        final base64Image = base64Encode(entry.value!);
        final result = await syncService.uploadReplacementImage(
          filename: entry.key,
          imageData: base64Image,
        );
        
        if (result != null && result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        debugPrint('Failed to upload ${entry.key}: $e');
      }
    }

    setState(() {
      _isUploading = false;
      _selectedImages.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload completed: $successCount successful, $failCount failed'),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}
