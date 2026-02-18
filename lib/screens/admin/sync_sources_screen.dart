import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/spot_attributes.dart';
import '../../services/auth_service.dart';
import '../../services/sync_source_service.dart';
import '../../widgets/spot_form/attributes_section.dart';

class SyncSourcesScreen extends StatefulWidget {
  const SyncSourcesScreen({super.key});

  @override
  State<SyncSourcesScreen> createState() => _SyncSourcesScreenState();
}

class _SyncSourcesScreenState extends State<SyncSourcesScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Defer the fetch call until after the build phase is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<SyncSourceService>();
      if (service.sources.isEmpty && !service.isLoading) {
        service.fetchSyncSources(includeInactive: true);
      }
      _startPeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    if (!mounted) return;
    
    // Cancel existing timer if any
    _refreshTimer?.cancel();
    
    final service = context.read<SyncSourceService>();
    final hasSyncInProgress = service.sources.any((s) => s.syncInProgress == true);
    
    // Use 5 seconds if sync is in progress, 30 seconds otherwise
    final interval = hasSyncInProgress 
        ? const Duration(seconds: 5) 
        : const Duration(seconds: 30);
    
    _refreshTimer = Timer.periodic(interval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Fetch latest sync sources
      await context.read<SyncSourceService>().fetchSyncSources(includeInactive: true);
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Check if sync status changed after fetch
      final currentService = context.read<SyncSourceService>();
      final stillHasSyncInProgress = currentService.sources.any((s) => s.syncInProgress == true);
      
      // If sync status changed, restart timer with new interval
      if (stillHasSyncInProgress != hasSyncInProgress) {
        timer.cancel();
        _startPeriodicRefresh(); // Restart with new interval
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
          Consumer<SyncSourceService>(
            builder: (context, service, child) {
              return PopupMenuButton<String>(
                icon: service.isSyncingAll 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync All',
                enabled: !service.isSyncingAll,
                onSelected: (mode) async {
                  if (!mounted) return;
                  final updateImages = mode == 'full';
                  final syncService = context.read<SyncSourceService>();
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await syncService.syncAllSources(
                    updateImagesForExistingSpots: updateImages,
                  );
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
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 20),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Default Sync'),
                            Text(
                              'Skip images for existing spots',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'full',
                    child: Row(
                      children: [
                        Icon(Icons.sync_problem, size: 20),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Full Sync'),
                            Text(
                              'Update images for existing spots',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
            icon: const Icon(Icons.search),
            tooltip: 'Backfill Spot Name Search (spotSearchTerms)',
            onPressed: () => _backfillSpotNameLower(context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Backfill Source Attributes',
            onPressed: () => _showBackfillSpotAttributesDialog(context),
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
                      if (s.publicUrl != null && s.publicUrl!.isNotEmpty) ...[
                        InkWell(
                          onTap: () async {
                            final uri = Uri.parse(s.publicUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                s.publicUrl!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (s.instagramHandle != null && s.instagramHandle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final handle = s.instagramHandle!.startsWith('@') 
                                ? s.instagramHandle!.substring(1) 
                                : s.instagramHandle!;
                            final uri = Uri.parse('https://instagram.com/$handle');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.camera_alt, size: 16, color: Colors.purple),
                              const SizedBox(width: 4),
                              Text(
                                '@${s.instagramHandle!.startsWith('@') ? s.instagramHandle!.substring(1) : s.instagramHandle!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(label: Text(s.isActive ? 'Active' : 'Inactive')),
                          if (s.syncInProgress == true) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Syncing ${s.syncType ?? 'unknown'}...'),
                                ],
                              ),
                              backgroundColor: Colors.orange.shade100,
                            ),
                          ] else if (s.autoSyncEnabled == true) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule, size: 16),
                                  SizedBox(width: 4),
                                  Text('Auto-Sync ON'),
                                ],
                              ),
                              backgroundColor: Colors.green.shade100,
                            ),
                          ],
                          if (s.lastSyncAt != null) ...[
                            const SizedBox(width: 8),
                            Chip(label: Text('Last sync: ${s.lastSyncAt}')),
                          ],
                        ],
                      ),
                      if (s.syncInProgress == true && s.syncProgress != null) ...[
                        const SizedBox(height: 8),
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.sync, size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sync in Progress (${s.syncType ?? 'unknown'})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (s.syncProgress!['totalCount'] != null &&
                                    s.syncProgress!['processedCount'] != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Progress: ${s.syncProgress!['processedCount']}/${s.syncProgress!['totalCount']} spots',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          Text(
                                            '${((s.syncProgress!['processedCount'] as num) / (s.syncProgress!['totalCount'] as num) * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: (s.syncProgress!['processedCount'] as num) /
                                            (s.syncProgress!['totalCount'] as num),
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                      ),
                                    ],
                                  )
                                else
                                  const Text(
                                    'Processing...',
                                    style: TextStyle(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (s.autoSyncEnabled == true) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('Auto-Sync Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (s.lightSyncSchedule != null && s.lightSyncSchedule!.isNotEmpty)
                              Chip(
                                label: Text('Light: ${s.lightSyncSchedule}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.blue.shade50,
                              ),
                            if (s.fullSyncSchedule != null && s.fullSyncSchedule!.isNotEmpty)
                              Chip(
                                label: Text('Full: ${s.fullSyncSchedule}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.purple.shade50,
                              ),
                          ],
                        ),
                        if (s.lastLightSyncAt != null || s.lastFullSyncAt != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (s.lastLightSyncAt != null)
                                Chip(
                                  label: Text('Last light sync: ${s.lastLightSyncAt}', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.blue.shade100,
                                ),
                              if (s.lastFullSyncAt != null)
                                Chip(
                                  label: Text('Last full sync: ${s.lastFullSyncAt}', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.purple.shade100,
                                ),
                            ],
                          ),
                        ],
                      ],
                      if (s.lastSyncStats != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('Last sync stats:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (s.lastSyncStats!['created'] != null)
                              Chip(
                                label: Text('Created: ${s.lastSyncStats!['created']}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.green.shade100,
                              ),
                            if (s.lastSyncStats!['updated'] != null)
                              Chip(
                                label: Text('Updated: ${s.lastSyncStats!['updated']}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.blue.shade100,
                              ),
                            if (s.lastSyncStats!['removed'] != null)
                              Chip(
                                label: Text('Removed: ${s.lastSyncStats!['removed']}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.red.shade100,
                              ),
                            if (s.lastSyncStats!['skipped'] != null)
                              Chip(
                                label: Text('Skipped: ${s.lastSyncStats!['skipped']}', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.orange.shade100,
                              ),
                            if (s.lastSyncStats!['total'] != null)
                              Chip(
                                label: Text('Total: ${s.lastSyncStats!['total']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.grey.shade200,
                              ),
                          ],
                        ),
                      ],
                      if (s.includeFolders != null && s.includeFolders!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('Include folders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ...s.includeFolders!.map((folder) => Chip(
                              label: Text(folder, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.green.shade100,
                            )),
                          ],
                        ),
                      ],
                      if (s.allFolders != null && s.allFolders!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text('All folders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ...s.allFolders!.map((folder) => Chip(
                              label: Text(folder, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.blue.shade100,
                            )),
                          ],
                        ),
                      ],
                      if ((s.defaultSpotAttributes?.isNotEmpty ?? false) ||
                          (s.folderSpotAttributes?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (s.defaultSpotAttributes?.isNotEmpty ?? false)
                              Chip(
                                label: const Text(
                                  'Source defaults enabled',
                                  style: TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.teal.shade100,
                              ),
                            if (s.folderSpotAttributes?.isNotEmpty ?? false)
                              Chip(
                                label: Text(
                                  'Folder defaults: ${s.folderSpotAttributes!.length}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.indigo.shade100,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.isActive && s.kmzUrl.isNotEmpty)
                        Consumer<SyncSourceService>(
                          builder: (context, service, child) {
                            final isThisSourceSyncing = service.syncingSources.contains(s.id);
                            // Show resume button if sync is in progress, otherwise show sync button
                            if (s.syncInProgress == true) {
                              return IconButton(
                                icon: isThisSourceSyncing 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.play_arrow),
                                tooltip: 'Resume sync',
                                onPressed: isThisSourceSyncing ? null : () async {
                                  if (!mounted) return;
                                  final syncService = context.read<SyncSourceService>();
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final result = await syncService.resumeSync(s.id);
                                  if (!mounted) return;
                                  if (result != null) {
                                    final stats = result['stats'] as Map<String, dynamic>?;
                                    final message = stats != null 
                                        ? '${s.name} sync resumed! Created: ${stats['created']}, Updated: ${stats['updated']}, Geocoded: ${stats['geocoded']}'
                                        : result['message'] ?? '${s.name} sync resumed successfully';
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
                                        content: Text(syncService.error ?? 'Resume sync failed for ${s.name}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              );
                            } else {
                              return PopupMenuButton<String>(
                                icon: isThisSourceSyncing 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.sync),
                                tooltip: 'Sync this source',
                                enabled: !isThisSourceSyncing,
                                onSelected: (mode) async {
                                  if (!mounted) return;
                                  final updateImages = mode == 'full';
                                  final syncService = context.read<SyncSourceService>();
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final result = await syncService.syncSingleSource(
                                    s.id,
                                    updateImagesForExistingSpots: updateImages,
                                  );
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
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: [
                                        Icon(Icons.sync, size: 20),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Default Sync'),
                                            Text(
                                              'Skip images for existing spots',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'full',
                                    child: Row(
                                      children: [
                                        Icon(Icons.sync_problem, size: 20),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Full Sync'),
                                            Text(
                                              'Update images for existing spots',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
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

    if (saved == true) {
      if (!mounted) return;
      final syncService = context.read<SyncSourceService>();
      if (!mounted) return;
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
      if (!mounted) return;
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
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!mounted) return;
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
        final navigator = Navigator.of(context);
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        navigator.pop(); // Close loading dialog
        scaffoldMessenger.showSnackBar(
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
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (!mounted) return;
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
      final navigator = Navigator.of(context);
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
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
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (!mounted) return;
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
            if (!mounted) return;
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
      final navigator = Navigator.of(context);
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
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

    if (confirmed == true) {
      if (!mounted) return;
      await _deleteSpot(context, spotId);
    }
  }

  Future<void> _deleteSpot(BuildContext context, String spotId) async {
    try {
      if (!mounted) return;
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
      if (!mounted) return;
      final result = await syncService.deleteSpot(spotId);

      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!mounted) return;
      navigator.pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Spot deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the orphaned spots dialog
        if (!mounted) return;
        final navigator2 = Navigator.of(context);
        if (!mounted) return;
        navigator2.pop(); // Close the orphaned spots dialog
        _showOrphanedSpotsDialog(context); // Reopen to show updated list
      } else {
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete spot: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
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

    if (confirmed == true) {
      if (!mounted) return;
      await _deleteAllSpots(context, orphanedSpots);
    }
  }

  Future<void> _deleteAllSpots(BuildContext context, List<dynamic> orphanedSpots) async {
    try {
      if (!mounted) return;
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
      if (!mounted) return;
      final result = await syncService.deleteSpots(spotIds);

      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!mounted) return;
      navigator.pop(); // Close loading dialog
      
      if (result != null && result['success'] == true) {
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Successfully deleted ${orphanedSpots.length} orphaned spots'),
            backgroundColor: Colors.green,
          ),
        );

        // Close the orphaned spots dialog
        if (!mounted) return;
        final navigator2 = Navigator.of(context);
        if (!mounted) return;
        navigator2.pop();
      } else {
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete spots: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete spots: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBackfillSpotAttributesDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backfill Source Attributes'),
          content: const Text(
            'This will apply configured source/folder default attributes to existing spots. '
            'If a matching source spot is marked as duplicateOf another spot, the defaults are also merged into that original spot.\n\n'
            'Do you want to backfill all sources or select one source?'
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
                await _runBackfillSpotAttributes(context, null);
              },
            ),
            TextButton(
              child: const Text('Select Source'),
              onPressed: () {
                Navigator.of(context).pop();
                _showBackfillSourceSelectionDialog(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackfillSourceSelectionDialog(BuildContext context) async {
    final syncService = context.read<SyncSourceService>();
    final sortedSources = [...syncService.sources]..sort((a, b) => a.name.compareTo(b.name));

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Source'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedSources.length,
              itemBuilder: (context, index) {
                final source = sortedSources[index];
                return ListTile(
                  title: Text(source.name),
                  subtitle: Text(source.id),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _runBackfillSpotAttributes(context, source.id);
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

  Future<void> _runBackfillSpotAttributes(BuildContext context, String? sourceId) async {
    final syncService = context.read<SyncSourceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
              Text('Backfilling source attributes...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await syncService.backfillSourceSpotAttributes(sourceId: sourceId);

      navigator.pop();

      if (!mounted) return;
      if (result != null && result['success'] == true) {
        final summary = result['summary'] as Map<String, dynamic>?;
        final message = summary != null
            ? 'Backfill done! Sources: ${summary['sourcesRequested']}, '
                'spots updated: ${summary['spotsUpdated']}, '
                'originals updated: ${summary['originalSpotsUpdated']}'
            : (result['message']?.toString() ?? 'Backfill completed');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
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
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Backfill failed: $e'),
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

  Future<void> _backfillSpotNameLower(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Backfill Spot Name Search'),
        content: const Text(
          'Populates spotSearchTerms for all spots (Explore autocomplete). '
          'Run once after deploying. This may take a few minutes for large databases.',
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
    if (confirm != true || !mounted) return;
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
      final result = await syncService.backfillSpotNameLower();
      navigator.pop();
      if (mounted) {
        if (result != null && result['success'] == true) {
          final stats = result['stats'] as Map<String, dynamic>?;
          final msg = stats != null
              ? 'Backfill completed. Spots: ${stats['totalProcessed']}, Terms: ${stats['searchTermsWritten']}'
              : 'Backfill completed';
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
        } else {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(syncService.error ?? 'Backfill failed'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      navigator.pop();
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Backfill failed: $e'), backgroundColor: Colors.red));
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
  late final TextEditingController folderRuleNameCtrl;
  late final TextEditingController lightSyncScheduleCtrl;
  late final TextEditingController fullSyncScheduleCtrl;
  late bool isActive;
  late bool recordFolderName;
  late bool autoSyncEnabled;
  late _EditableSpotAttributes _sourceDefaultAttributes;
  final Map<String, _EditableSpotAttributes> _folderDefaultAttributes = {};

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
    folderRuleNameCtrl = TextEditingController();
    lightSyncScheduleCtrl = TextEditingController(text: widget.source?.lightSyncSchedule ?? '');
    fullSyncScheduleCtrl = TextEditingController(text: widget.source?.fullSyncSchedule ?? '');
    isActive = widget.source?.isActive ?? true;
    recordFolderName = widget.source?.recordFolderName ?? false;
    autoSyncEnabled = widget.source?.autoSyncEnabled ?? false;
    _sourceDefaultAttributes = _EditableSpotAttributes.fromMap(
      widget.source?.defaultSpotAttributes,
    );
    final existingFolderDefaults = widget.source?.folderSpotAttributes ?? const {};
    for (final entry in existingFolderDefaults.entries) {
      final folderName = entry.key.trim();
      if (folderName.isEmpty) continue;
      _folderDefaultAttributes[folderName] = _EditableSpotAttributes.fromMap(
        entry.value,
      );
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    descCtrl.dispose();
    publicUrlCtrl.dispose();
    instagramHandleCtrl.dispose();
    includeFoldersCtrl.dispose();
    folderRuleNameCtrl.dispose();
    lightSyncScheduleCtrl.dispose();
    fullSyncScheduleCtrl.dispose();
    super.dispose();
  }

  String? _findExistingFolderRuleKey(String folderName) {
    final target = folderName.trim().toLowerCase();
    for (final key in _folderDefaultAttributes.keys) {
      if (key.trim().toLowerCase() == target) {
        return key;
      }
    }
    return null;
  }

  void _addFolderRule(String rawFolderName) {
    final folderName = rawFolderName.trim();
    if (folderName.isEmpty) return;

    final existingKey = _findExistingFolderRuleKey(folderName);
    if (existingKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder rule for "$existingKey" already exists'),
        ),
      );
      return;
    }

    setState(() {
      _folderDefaultAttributes[folderName] = _EditableSpotAttributes.empty();
      folderRuleNameCtrl.clear();
    });
  }

  Map<String, dynamic>? _serializeFolderDefaultAttributes() {
    final result = <String, dynamic>{};
    for (final entry in _folderDefaultAttributes.entries) {
      final serialized = entry.value.toMapOrNull();
      if (serialized != null) {
        result[entry.key] = serialized;
      }
    }
    return result.isEmpty ? null : result;
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
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Default Spot Attributes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Applied to all newly created spots in this source.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              SpotAttributesSection(
                selectedAccess: _sourceDefaultAttributes.selectedAccess,
                selectedFeatures: _sourceDefaultAttributes.selectedFeatures,
                selectedFacilities: _sourceDefaultAttributes.selectedFacilities,
                selectedGoodFor: _sourceDefaultAttributes.selectedGoodFor,
                onAccessChanged: (value) {
                  setState(() {
                    _sourceDefaultAttributes.selectedAccess = value;
                  });
                },
                onToggleFeature: (key, selected) {
                  setState(() {
                    if (selected) {
                      _sourceDefaultAttributes.selectedFeatures.add(key);
                    } else {
                      _sourceDefaultAttributes.selectedFeatures.remove(key);
                    }
                  });
                },
                onFacilityChanged: (key, value) {
                  setState(() {
                    if (value == 'unknown') {
                      _sourceDefaultAttributes.selectedFacilities.remove(key);
                    } else {
                      _sourceDefaultAttributes.selectedFacilities[key] = value;
                    }
                  });
                },
                onToggleGoodFor: (key, selected) {
                  setState(() {
                    if (selected) {
                      _sourceDefaultAttributes.selectedGoodFor.add(key);
                    } else {
                      _sourceDefaultAttributes.selectedGoodFor.remove(key);
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Folder-specific Defaults',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Optional overrides/additions for newly created spots in specific folders.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: folderRuleNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Folder name',
                        hintText: 'e.g. Dry spots',
                      ),
                      onFieldSubmitted: _addFolderRule,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addFolderRule(folderRuleNameCtrl.text),
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (widget.source?.allFolders != null &&
                  widget.source!.allFolders!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.source!.allFolders!
                        .where((folder) =>
                            _findExistingFolderRuleKey(folder) == null)
                        .map((folder) => ActionChip(
                              label: Text(folder),
                              onPressed: () => _addFolderRule(folder),
                            ))
                        .toList(),
                  ),
                ),
              ],
              if (_folderDefaultAttributes.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._folderDefaultAttributes.entries.map((entry) {
                  final folderName = entry.key;
                  final folderAttributes = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(folderName),
                      subtitle: Text(folderAttributes.summary),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _folderDefaultAttributes.remove(folderName);
                              });
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Remove rule'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: SpotAttributesSection(
                            selectedAccess:
                                folderAttributes.selectedAccess,
                            selectedFeatures:
                                folderAttributes.selectedFeatures,
                            selectedFacilities:
                                folderAttributes.selectedFacilities,
                            selectedGoodFor:
                                folderAttributes.selectedGoodFor,
                            onAccessChanged: (value) {
                              setState(() {
                                folderAttributes.selectedAccess = value;
                              });
                            },
                            onToggleFeature: (key, selected) {
                              setState(() {
                                if (selected) {
                                  folderAttributes.selectedFeatures.add(key);
                                } else {
                                  folderAttributes.selectedFeatures.remove(key);
                                }
                              });
                            },
                            onFacilityChanged: (key, value) {
                              setState(() {
                                if (value == 'unknown') {
                                  folderAttributes.selectedFacilities.remove(key);
                                } else {
                                  folderAttributes.selectedFacilities[key] = value;
                                }
                              });
                            },
                            onToggleGoodFor: (key, selected) {
                              setState(() {
                                if (selected) {
                                  folderAttributes.selectedGoodFor.add(key);
                                } else {
                                  folderAttributes.selectedGoodFor.remove(key);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
              const Divider(),
              const Text(
                'Auto-Sync Configuration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Auto-Sync'),
                subtitle: const Text('Automatically sync this source according to schedules below'),
                value: autoSyncEnabled,
                onChanged: (v) => setState(() => autoSyncEnabled = v),
              ),
              TextFormField(
                controller: lightSyncScheduleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Light Sync Schedule (Cron)',
                  helperText: 'Cron expression for light sync (e.g., "0 2 */3 * *" for every 3 days at 2 AM UTC). Leave empty to disable.',
                ),
              ),
              TextFormField(
                controller: fullSyncScheduleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Sync Schedule (Cron)',
                  helperText: 'Cron expression for full sync (e.g., "0 3 * * 0" for weekly on Sunday at 3 AM UTC). Leave empty to disable.',
                ),
              ),
              if (widget.source != null) ...[
                const SizedBox(height: 8),
                if (widget.source!.lastLightSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Text('Last light sync: ', style: TextStyle(fontSize: 12)),
                        Text(
                          widget.source!.lastLightSyncAt.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (widget.source!.lastFullSyncAt != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Text('Last full sync: ', style: TextStyle(fontSize: 12)),
                        Text(
                          widget.source!.lastFullSyncAt.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
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
            final sourceDefaultAttributesPayload =
                _sourceDefaultAttributes.toMapOrNull();
            final folderDefaultAttributesPayload =
                _serializeFolderDefaultAttributes();
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
                defaultSpotAttributes: sourceDefaultAttributesPayload,
                folderSpotAttributes: folderDefaultAttributesPayload,
                lightSyncSchedule: lightSyncScheduleCtrl.text.trim().isEmpty ? null : lightSyncScheduleCtrl.text.trim(),
                fullSyncSchedule: fullSyncScheduleCtrl.text.trim().isEmpty ? null : fullSyncScheduleCtrl.text.trim(),
                autoSyncEnabled: autoSyncEnabled,
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
                defaultSpotAttributes: sourceDefaultAttributesPayload,
                folderSpotAttributes: folderDefaultAttributesPayload,
                updateSpotAttributeDefaults: true,
                lightSyncSchedule: lightSyncScheduleCtrl.text.trim(),
                fullSyncSchedule: fullSyncScheduleCtrl.text.trim(),
                autoSyncEnabled: autoSyncEnabled,
              );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Saved' : 'Failed to save')),
              );
            }
            if (context.mounted) {
              Navigator.pop(context, ok);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditableSpotAttributes {
  _EditableSpotAttributes({
    required this.selectedAccess,
    required Set<String> selectedFeatures,
    required Map<String, String> selectedFacilities,
    required Set<String> selectedGoodFor,
  })  : selectedFeatures = selectedFeatures,
        selectedFacilities = selectedFacilities,
        selectedGoodFor = selectedGoodFor;

  factory _EditableSpotAttributes.empty() {
    return _EditableSpotAttributes(
      selectedAccess: null,
      selectedFeatures: <String>{},
      selectedFacilities: <String, String>{},
      selectedGoodFor: <String>{},
    );
  }

  factory _EditableSpotAttributes.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return _EditableSpotAttributes.empty();
    }

    final validAccess = SpotAttributes.getKeys('access').toSet();
    final validFeatures = SpotAttributes.getKeys('features').toSet();
    final validGoodFor = SpotAttributes.getKeys('goodFor').toSet();
    final validFacilities = SpotAttributes.getKeys('facilities').toSet();

    String? selectedAccess;
    final rawAccess = map['spotAccess'];
    if (rawAccess is String && validAccess.contains(rawAccess)) {
      selectedAccess = rawAccess;
    }

    final selectedFeatures = <String>{};
    final rawFeatures = map['spotFeatures'];
    if (rawFeatures is List) {
      for (final value in rawFeatures) {
        if (value is String && validFeatures.contains(value)) {
          selectedFeatures.add(value);
        }
      }
    }

    final selectedGoodFor = <String>{};
    final rawGoodFor = map['goodFor'];
    if (rawGoodFor is List) {
      for (final value in rawGoodFor) {
        if (value is String && validGoodFor.contains(value)) {
          selectedGoodFor.add(value);
        }
      }
    }

    final selectedFacilities = <String, String>{};
    final rawFacilities = map['spotFacilities'];
    if (rawFacilities is Map) {
      for (final entry in rawFacilities.entries) {
        final key = entry.key.toString();
        final value = entry.value?.toString();
        if (!validFacilities.contains(key)) continue;
        if (value == 'yes' || value == 'no') {
          selectedFacilities[key] = value!;
        }
      }
    }

    return _EditableSpotAttributes(
      selectedAccess: selectedAccess,
      selectedFeatures: selectedFeatures,
      selectedFacilities: selectedFacilities,
      selectedGoodFor: selectedGoodFor,
    );
  }

  String? selectedAccess;
  final Set<String> selectedFeatures;
  final Map<String, String> selectedFacilities;
  final Set<String> selectedGoodFor;

  Map<String, dynamic>? toMapOrNull() {
    final map = <String, dynamic>{};
    if (selectedAccess != null && selectedAccess!.isNotEmpty) {
      map['spotAccess'] = selectedAccess;
    }
    if (selectedFeatures.isNotEmpty) {
      final list = selectedFeatures.toList()..sort();
      map['spotFeatures'] = list;
    }
    if (selectedGoodFor.isNotEmpty) {
      final list = selectedGoodFor.toList()..sort();
      map['goodFor'] = list;
    }
    if (selectedFacilities.isNotEmpty) {
      final cleaned = <String, String>{};
      for (final entry in selectedFacilities.entries) {
        if (entry.value == 'yes' || entry.value == 'no') {
          cleaned[entry.key] = entry.value;
        }
      }
      if (cleaned.isNotEmpty) {
        map['spotFacilities'] = cleaned;
      }
    }
    return map.isEmpty ? null : map;
  }

  String get summary {
    final parts = <String>[];
    if (selectedAccess != null) {
      parts.add('Access: ${SpotAttributes.getLabel('access', selectedAccess!)}');
    }
    if (selectedFeatures.isNotEmpty) {
      parts.add('${selectedFeatures.length} feature${selectedFeatures.length == 1 ? '' : 's'}');
    }
    if (selectedGoodFor.isNotEmpty) {
      parts.add('${selectedGoodFor.length} good-for');
    }
    if (selectedFacilities.isNotEmpty) {
      parts.add('${selectedFacilities.length} facilit${selectedFacilities.length == 1 ? 'y' : 'ies'}');
    }
    return parts.isEmpty ? 'No attributes configured' : parts.join(' • ');
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
                    title: SelectableText(filename),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Referenced by ${spots.length} spot(s):'),
                        ...spots.map((spot) => SelectableText(
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
