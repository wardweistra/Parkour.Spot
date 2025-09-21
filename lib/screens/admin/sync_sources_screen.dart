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
    final service = context.read<SyncSourceService>();
    if (service.sources.isEmpty && !service.isLoading) {
      service.fetchSyncSources(includeInactive: true);
    }
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
                  final result = await context.read<SyncSourceService>().syncAllSources();
                  if (mounted) {
                    if (result != null) {
                      final stats = result['totalStats'] as Map<String, dynamic>?;
                      final message = stats != null 
                          ? 'Sync completed! Created: ${stats['created']}, Updated: ${stats['updated']}, Geocoded: ${stats['geocoded']}'
                          : 'Sync completed successfully';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(service.error ?? 'Sync failed'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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
          final sources = service.sources;
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
                          const SizedBox(width: 8),
                          Chip(label: Text(s.isPublic ? 'Public' : 'Private')),
                          if (s.lastSyncAt != null) ...[
                            const SizedBox(width: 8),
                            Chip(label: Text('Last sync: ${s.lastSyncAt}')),
                          ],
                        ],
                      ),
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
                                final result = await context.read<SyncSourceService>().syncSingleSource(s.id);
                                if (mounted) {
                                  if (result != null) {
                                    final stats = result['stats'] as Map<String, dynamic>?;
                                    final message = stats != null 
                                        ? '${s.name} sync completed! Created: ${stats['created']}, Updated: ${stats['updated']}, Geocoded: ${stats['geocoded']}'
                                        : '${s.name} sync completed successfully';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(service.error ?? 'Sync failed for ${s.name}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'edit':
                              _openEditDialog(context, source: s);
                              break;
                            case 'toggleActive':
                              await context.read<SyncSourceService>().updateSource(
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
                                await context.read<SyncSourceService>().deleteSource(s.id);
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
                  color: Colors.black.withOpacity(0.3),
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
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: source?.name ?? '');
    final urlCtrl = TextEditingController(text: source?.kmzUrl ?? '');
    final descCtrl = TextEditingController(text: source?.description ?? '');
    bool isPublic = source?.isPublic ?? true;
    bool isActive = source?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(source == null ? 'Add Source' : 'Edit Source'),
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
                  decoration: const InputDecoration(labelText: 'KMZ URL'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Public'),
                        value: isPublic,
                        onChanged: (v) => setState(() => isPublic = v),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setState(() => isActive = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final service = context.read<SyncSourceService>();
              bool ok;
              if (source == null) {
                ok = await service.createSource(
                  name: nameCtrl.text.trim(),
                  kmzUrl: urlCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  isPublic: isPublic,
                  isActive: isActive,
                );
              } else {
                ok = await service.updateSource(
                  sourceId: source.id,
                  name: nameCtrl.text.trim(),
                  kmzUrl: urlCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  isPublic: isPublic,
                  isActive: isActive,
                );
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Saved' : 'Failed to save')),
                );
              }
              Navigator.pop(c, ok);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await context.read<SyncSourceService>().fetchSyncSources(includeInactive: true);
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
              'This will move all unused images to /spots/trash folder.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'The function will:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• List all files in /spots folder', style: TextStyle(fontSize: 12)),
            Text('• List all image files referenced by spots', style: TextStyle(fontSize: 12)),
            Text('• Move unreferenced images to /spots/trash', style: TextStyle(fontSize: 12)),
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
        final cleanupResult = await context.read<SyncSourceService>().cleanupUnusedImages();
        
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          if (cleanupResult != null && cleanupResult['success'] == true) {
            final movedCount = cleanupResult['movedCount'] ?? 0;
            final skippedCount = cleanupResult['skippedCount'] ?? 0;
            final totalFiles = cleanupResult['totalFiles'] ?? 0;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cleanup completed: $movedCount images moved to trash, $skippedCount skipped (out of $totalFiles total)',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cleanup failed: ${cleanupResult?['error'] ?? 'Unknown error'}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleanup failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      final result = await context.read<SyncSourceService>().findMissingImages();
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (result != null && result['success'] == true) {
          final missingImages = result['missingImages'] as List<dynamic>? ?? [];
          final totalReferenced = result['totalReferencedImages'] ?? 0;
          final totalExisting = result['totalExistingFiles'] ?? 0;
          final missingCount = result['missingImagesCount'] ?? 0;
          
          if (missingCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No missing images found! All referenced images exist.'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Navigate to missing images screen
            Navigator.push(
              context,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check missing images: ${result?['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check missing images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadSelectedImages() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _isUploading = true;
    });

    int successCount = 0;
    int failCount = 0;

    for (final entry in _selectedImages.entries) {
      if (entry.value == null) continue;
      
      try {
        final base64Image = base64Encode(entry.value!);
        final result = await context.read<SyncSourceService>().uploadReplacementImage(
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

