import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/admin_notifications_service.dart';
import '../../services/auth_service.dart';
import '../../utils/user_notification_localization.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<AdminNotificationsService>();
      if (service.entries.isEmpty && !service.isLoading) {
        service.fetchInitial();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('All notifications')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All notifications'),
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
          Consumer<AdminNotificationsService>(
            builder: (context, service, _) {
              return IconButton(
                tooltip: 'Refresh',
                icon: service.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: service.isLoading
                    ? null
                    : () => service.fetchInitial(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminNotificationsService>(
        builder: (context, service, _) {
          if (service.isLoading && service.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(service.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => service.fetchInitial(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (service.entries.isEmpty && !service.hasMore) {
            return RefreshIndicator(
              onRefresh: () => service.fetchInitial(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications in the database',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final showLoadMore = service.hasMore;
          final itemCount = service.entries.length + (showLoadMore ? 1 : 0);

          return RefreshIndicator(
            onRefresh: () => service.fetchInitial(forceRefresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= service.entries.length) {
                  return _AdminNotificationsLoadMoreFooter(service: service);
                }
                final entry = service.entries[index];
                return _AdminNotificationCard(
                  entry: entry,
                  l10n: l10n,
                  onDelete: () => _confirmDelete(context, service, entry),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminNotificationsService service,
    AdminNotificationEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete notification'),
        content: const Text(
          'Remove this notification from the recipient’s inbox? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    final success = await service.deleteNotification(entry);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Notification deleted' : 'Failed to delete'),
        backgroundColor: success ? null : Colors.red,
      ),
    );
  }
}

class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({
    required this.entry,
    required this.l10n,
    required this.onDelete,
  });

  final AdminNotificationEntry entry;
  final AppLocalizations l10n;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final n = entry.notification;
    final copy = localizedUserNotificationCopy(n, l10n);
    final timeLabel = _formatCreatedAt(n.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.title.isNotEmpty ? copy.title : '(no title)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (copy.body != null && copy.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      copy.body!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SelectableText(
                    'Recipient: ${entry.recipientUserId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${n.deeplinkKind.name} · ${n.deeplinkId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (n.notificationKind != null && n.notificationKind!.isNotEmpty)
                        Chip(
                          label: Text(n.notificationKind!, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      Chip(
                        label: Text(n.read ? 'Read' : 'Unread', style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCreatedAt(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Time unknown';
    }
    return '${DateFormat.yMMMd().add_Hms().format(createdAt.toUtc())} UTC';
  }
}

class _AdminNotificationsLoadMoreFooter extends StatelessWidget {
  const _AdminNotificationsLoadMoreFooter({required this.service});

  final AdminNotificationsService service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: service.isLoadingMore
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.icon(
                onPressed: () => service.loadMore(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
      ),
    );
  }
}
