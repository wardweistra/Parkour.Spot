import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/admin_push_subscription_summary.dart';
import '../../models/user.dart' as app_user;
import '../../services/admin_push_subscriptions_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_management_service.dart';

/// Admin: pick a user, inspect their [pushSubscriptions], send a web push to a subset.
class AdminPushSubscriptionsScreen extends StatefulWidget {
  const AdminPushSubscriptionsScreen({super.key});

  @override
  State<AdminPushSubscriptionsScreen> createState() =>
      _AdminPushSubscriptionsScreenState();
}

class _AdminPushSubscriptionsScreenState
    extends State<AdminPushSubscriptionsScreen> {
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(
    text: 'Parkour·Spot',
  );
  final TextEditingController _bodyController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String _userFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final users = context.read<UserManagementService>();
      if (users.users.isEmpty && !users.isLoading) {
        users.fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _uidController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<app_user.User> _filteredUsers(List<app_user.User> all) {
    final q = _userFilter.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((u) {
      if (u.id.toLowerCase().contains(q)) return true;
      if ((u.email).toLowerCase().contains(q)) return true;
      final dn = u.displayName?.toLowerCase() ?? '';
      if (dn.contains(q)) return true;
      final un = u.username?.toLowerCase() ?? '';
      if (un.contains(q)) return true;
      return false;
    }).toList();
  }

  Future<void> _loadSubscriptions(
    AdminPushSubscriptionsService pushService,
  ) async {
    final uid = _uidController.text.trim();
    pushService.setTargetUid(uid);
    _selectedIds.clear();
    await pushService.fetchSubscriptionsForTarget(uid);
    if (mounted) setState(() {});
  }

  Future<void> _send(
    BuildContext context,
    AdminPushSubscriptionsService pushService,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await pushService.sendToSubscriptions(
      subscriptionIds: _selectedIds.toList(growable: false),
      title: _titleController.text,
      body: _bodyController.text,
    );
    if (!context.mounted) return;
    final msg = pushService.error ?? pushService.lastSendSummary ?? 'Done';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatMillis(int? ms) {
    if (ms == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Web push (admin)')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web push subscriptions'),
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
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildUserPickerColumn(context),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: _buildSubscriptionsColumn(context),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildUserPickerColumn(context),
                          const SizedBox(height: 24),
                          _buildSubscriptionsColumn(context),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserPickerColumn(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose user', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filter loaded users',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _userFilter = v),
            ),
            const SizedBox(height: 12),
            Consumer<UserManagementService>(
              builder: (context, users, _) {
                if (users.isLoading && users.users.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final filtered = _filteredUsers(users.users);
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      final subtitle = u.email.isNotEmpty
                          ? u.email
                          : (u.username ?? '');
                      return ListTile(
                        dense: true,
                        title: Text(u.displayName ?? u.id),
                        subtitle: Text(
                          subtitle.isEmpty ? u.id : '$subtitle · ${u.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _uidController.text = u.id;
                          setState(() {});
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Target user id (uid)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Consumer<AdminPushSubscriptionsService>(
              builder: (context, pushService, _) {
                return FilledButton.icon(
                  onPressed: pushService.isLoadingList
                      ? null
                      : () => _loadSubscriptions(pushService),
                  icon: pushService.isLoadingList
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Load push subscriptions'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsColumn(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<AdminPushSubscriptionsService>(
          builder: (context, pushService, _) {
            if (pushService.error != null &&
                pushService.subscriptions.isEmpty) {
              return Text(
                pushService.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }
            if (pushService.subscriptions.isEmpty) {
              return Text(
                pushService.targetUid == null
                    ? 'Enter a user id and load subscriptions.'
                    : 'No push subscription documents for this user.',
                style: Theme.of(context).textTheme.bodyLarge,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${pushService.subscriptions.length} subscription(s) for '
                  '${pushService.targetUid}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...pushService.subscriptions.map(
                  (s) => _subscriptionTile(context, s),
                ),
                const Divider(height: 32),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notification title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Notification body',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: pushService.isSending || _selectedIds.isEmpty
                      ? null
                      : () => _send(context, pushService),
                  icon: pushService.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send to selected'),
                ),
                if (pushService.lastSendSummary != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    pushService.lastSendSummary!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _subscriptionTile(
    BuildContext context,
    AdminPushSubscriptionSummary s,
  ) {
    final selected = _selectedIds.contains(s.id);
    final canSelect = s.enabled && s.tokenSuffix != null;
    final meta = [
      if (s.isMobileDevice) 'mobile',
      if (s.isAndroid) 'Android',
      if (s.isIOS) 'iOS',
      if (s.isRunningAsPWA) 'PWA',
      if (s.isRunningInBrowser) 'browser tab',
    ].join(', ');

    return CheckboxListTile(
      value: selected,
      onChanged: canSelect
          ? (v) {
              setState(() {
                if (v == true) {
                  _selectedIds.add(s.id);
                } else {
                  _selectedIds.remove(s.id);
                }
              });
            }
          : null,
      secondary: Icon(
        s.enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: s.enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        'Installation ${s.id.substring(0, 8)}…'
        '${s.tokenSuffix != null ? ' · …${s.tokenSuffix}' : ''}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        [
          s.enabled ? 'enabled' : 'disabled',
          if (s.permission != null) s.permission!,
          if (meta.isNotEmpty) meta,
          'updated ${_formatMillis(s.updatedAtMillis)}',
        ].join(' · '),
        maxLines: 3,
      ),
    );
  }
}
