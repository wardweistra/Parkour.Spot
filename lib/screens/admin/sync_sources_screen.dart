import 'package:flutter/material.dart';
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
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync All',
            onPressed: () async {
              final ok = await context.read<SyncSourceService>().syncAllSources();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Sync started' : 'Failed to start sync')),
                );
              }
            },
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
          return ListView.separated(
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
                  trailing: PopupMenuButton<String>(
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
                ),
              );
            },
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
}

