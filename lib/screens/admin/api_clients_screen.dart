import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/api_client_service.dart';

class ApiClientsScreen extends StatefulWidget {
  const ApiClientsScreen({super.key});

  @override
  State<ApiClientsScreen> createState() => _ApiClientsScreenState();
}

class _ApiClientsScreenState extends State<ApiClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<ApiClientService>();
      if (service.clients.isEmpty && !service.isLoading) {
        service.fetchClients();
      }
    });
  }

  Future<void> _addClient(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClientService = context.read<ApiClientService>();
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add API Client'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Client name',
            hintText: 'e.g. Partner App XYZ',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Creating API client...')),
      );
      final data = await apiClientService.createClient(result);
      if (!context.mounted) return;
      final apiKey = data?['apiKey'] as String?;
      final warning = data?['warning'] as String?;
      _showApiKeyDialog(
        context: context,
        title: 'API Client Created',
        apiKey: apiKey ?? '',
        warning: warning,
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showApiKeyDialog({
    required BuildContext context,
    required String title,
    required String apiKey,
    String? warning,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (warning != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'API Key:',
                style: TextStyle(),
              ),
              const SizedBox(height: 8),
              SelectableText(
                apiKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: apiKey));
                        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateKey(BuildContext context, ApiClient client) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClientService = context.read<ApiClientService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate API Key'),
        content: Text(
          'This will invalidate the current API key for "${client.name}". '
          'The new key will be shown once. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Regenerating API key...')),
      );
      final apiKey = await apiClientService.regenerateKey(client.id);
      if (!context.mounted) return;
      _showApiKeyDialog(
        context: context,
        title: 'New API Key',
        apiKey: apiKey ?? '',
        warning: 'Save this API key. It will not be shown again. Previous key is now invalid.',
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteClient(BuildContext context, ApiClient client) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final apiClientService = context.read<ApiClientService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete API Client'),
        content: Text(
          'Delete "${client.name}"? This will revoke their API access. Usage history will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await apiClientService.deleteClient(client.id);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('API client deleted'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('API clients')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API clients'),
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
          Consumer<ApiClientService>(
            builder: (context, service, _) => IconButton(
              tooltip: 'Refresh',
              icon: service.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: service.isLoading ? null : () => service.fetchClients(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Client',
            onPressed: () => _addClient(context),
          ),
        ],
      ),
      body: Consumer<ApiClientService>(
        builder: (context, service, _) {
          if (service.isLoading && service.clients.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.error != null && service.clients.isEmpty) {
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

          if (service.clients.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.api, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No API clients yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add clients to grant access to the Spot Details API',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _addClient(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Client'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: service.clients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final client = service.clients[index];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(client.name)),
                      Chip(
                        label: Text(
                          client.active ? 'Active' : 'Inactive',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: client.active
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (client.lastUsedAt != null)
                        Text(
                          'Last used: ${_formatDate(client.lastUsedAt!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _usageChip('Total', client.totalCalls),
                          _usageChip('7d', client.last7Days),
                          _usageChip('30d', client.last30Days),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final messenger = ScaffoldMessenger.of(context);
                      switch (value) {
                        case 'toggle':
                          await service.updateClient(
                            clientId: client.id,
                            active: !client.active,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                client.active
                                    ? 'Client deactivated'
                                    : 'Client activated',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          break;
                        case 'regenerate':
                          await _regenerateKey(context, client);
                          break;
                        case 'delete':
                          await _deleteClient(context, client);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(client.active ? Icons.block : Icons.check_circle),
                            const SizedBox(width: 8),
                            Text(client.active ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'regenerate',
                        child: Row(
                          children: [
                            Icon(Icons.key, size: 20),
                            SizedBox(width: 8),
                            Text('Regenerate API Key'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
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

  Widget _usageChip(String label, int count) {
    return Chip(
      label: Text('$label: $count', style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
