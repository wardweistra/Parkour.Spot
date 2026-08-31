import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user_notification.dart';
import '../../services/user_notification_service.dart';
import '../../services/web_push_subscription_service.dart';
import '../../utils/user_notification_localization.dart';
import '../../widgets/page_scaffold.dart';

/// Corner radius for notification rows (matches common controls in the app).
const BorderRadius _kNotificationRowRadius = BorderRadius.all(
  Radius.circular(12),
);

/// Vertical space between notification rows (no dividers—rounded tiles + tint separate items).
const double _kNotificationRowSpacing = 6;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _streamRetryGeneration = 0;
  bool _showUnreadOnly = false;
  bool _pushPromptDismissed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationService = context.read<UserNotificationService>();
    final pushService = context.watch<WebPushSubscriptionService>();

    return StreamBuilder<List<UserNotification>>(
      key: ValueKey(_streamRetryGeneration),
      initialData: notificationService.latestNotifications,
      stream: notificationService.watchNotifications(),
      builder: (context, snapshot) {
        return PageScaffold(
          title: l10n.notificationsTitle,
          scrollable: false,
          centerContent: false,
          onBack: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/explore?tab=profile');
            }
          },
          actions: _appBarActions(context, l10n, snapshot),
          body: _buildBody(context, l10n, snapshot, pushService),
        );
      },
    );
  }

  bool _shouldShowPushPrompt(WebPushSubscriptionService push) {
    if (_pushPromptDismissed) return false;
    if (!push.isSupported || push.isSubscribed) return false;
    if (push.isBusy && push.permissionState == WebPushPermissionState.unknown) {
      return false;
    }
    return true;
  }

  List<Widget>? _appBarActions(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<List<UserNotification>> snapshot,
  ) {
    if (snapshot.hasError) return null;
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return null;
    }
    final items = snapshot.data ?? const <UserNotification>[];
    final actions = <Widget>[];

    if (items.isNotEmpty) {
      final unread = items.where((n) => !n.read).length;
      if (unread > 0) {
        actions.add(
          IconButton(
            tooltip: l10n.notificationsMarkAllRead,
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final service = context.read<UserNotificationService>();
              final ok = await service.markAllAsRead();
              if (!context.mounted) return;
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.notificationsMarkAllReadFailed)),
                );
              }
            },
          ),
        );
      }
      actions.add(
        IconButton(
          tooltip: _showUnreadOnly
              ? l10n.notificationsShowAll
              : l10n.notificationsUnreadOnly,
          icon: Icon(
            _showUnreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          onPressed: () {
            setState(() => _showUnreadOnly = !_showUnreadOnly);
          },
        ),
      );
    }

    actions.add(
      IconButton(
        tooltip: l10n.profileNotificationSettingsTitle,
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => context.push('/profile/settings'),
      ),
    );

    return actions;
  }

  Future<void> _enablePushFromInbox(BuildContext context) async {
    final push = context.read<WebPushSubscriptionService>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await push.enableCurrentDevice();
    if (!context.mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.notificationsPushPromptEnabledSnackbar)),
      );
      return;
    }
    if (push.permissionState != WebPushPermissionState.denied) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profilePushNotificationsError)),
      );
    }
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<List<UserNotification>> snapshot,
    WebPushSubscriptionService pushService,
  ) {
    if (snapshot.hasError) {
      final err = snapshot.error;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.notificationsLoadError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (kDebugMode && err != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    err.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _streamRetryGeneration++);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.notificationsRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _NotificationsLoadingSkeleton();
    }

    final items = snapshot.data ?? const <UserNotification>[];
    final displayItems = _showUnreadOnly
        ? items.where((n) => !n.read).toList(growable: false)
        : items;
    final showPushPrompt = _shouldShowPushPrompt(pushService);
    final pushBlocked =
        pushService.permissionState == WebPushPermissionState.denied;

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 56,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.notificationsEmptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notificationsEmptyBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showPushPrompt) ...[
                  const SizedBox(height: 20),
                  if (pushBlocked) ...[
                    Text(
                      l10n.notificationsPushPromptBlockedTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.notificationsPushPromptBlockedBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    Text(
                      l10n.notificationsPushPromptEmptyHelper,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: pushService.isBusy
                        ? null
                        : () {
                            if (pushBlocked) {
                              context.push('/profile/settings');
                            } else {
                              unawaited(_enablePushFromInbox(context));
                            }
                          },
                    child: Text(
                      pushBlocked
                          ? l10n.profileNotificationSettingsTitle
                          : l10n.notificationsPushPromptTurnOnEmpty,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _pushPromptDismissed = true);
                    },
                    child: Text(l10n.notificationsPushPromptNotNow),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            if (showPushPrompt)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _InboxPushListCallout(
                  blocked: pushBlocked,
                  busy: pushService.isBusy,
                  onTurnOn: () => unawaited(_enablePushFromInbox(context)),
                  onOpenSettings: () => context.push('/profile/settings'),
                  onDismiss: () {
                    setState(() => _pushPromptDismissed = true);
                  },
                ),
              ),
            Expanded(
              child: displayItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                size: 56,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.notificationsEmptyFilteredTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.notificationsEmptyFilteredBody,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: displayItems.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: _kNotificationRowSpacing),
                      itemBuilder: (context, index) {
                        final item = displayItems[index];
                        return _NotificationListTile(
                          item: item,
                          timeLabel: _formatTimestamp(
                            context,
                            item.createdAt,
                            l10n,
                          ),
                          onOpen: () => _openNotification(context, item),
                          onLongPress: item.read
                              ? () => unawaited(
                                  _markNotificationUnread(context, item),
                                )
                              : () => unawaited(
                                  _markNotificationReadOnly(context, item),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(
    BuildContext context,
    DateTime? at,
    AppLocalizations l10n,
  ) {
    if (at == null) return l10n.notificationsTimeUnknown;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
  }

  Future<void> _markNotificationUnread(
    BuildContext context,
    UserNotification item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<UserNotificationService>().markAsUnread(
      item.id,
    );
    if (!context.mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.notificationsMarkAsUnreadFailed)),
      );
    }
  }

  /// Long-press on unread row: mark read without opening the deeplink.
  Future<void> _markNotificationReadOnly(
    BuildContext context,
    UserNotification item,
  ) async {
    if (item.read) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<UserNotificationService>().markAsRead(
      item.id,
    );
    if (!context.mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.notificationsMarkAsReadFailed)),
      );
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    UserNotification item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (item.deeplinkId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.notificationsOpenFailedSnackbar)),
      );
      return;
    }

    final notificationService = context.read<UserNotificationService>();

    if (!item.read) {
      final ok = await notificationService.markAsRead(item.id);
      if (!context.mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationsMarkAsReadFailed)),
        );
      }
    }
    if (!context.mounted) return;

    switch (item.deeplinkKind) {
      case UserNotificationDeeplinkKind.spot:
        context.push('/spot/${item.deeplinkId}');
      case UserNotificationDeeplinkKind.event:
        context.push('/event/${item.deeplinkId}');
      case UserNotificationDeeplinkKind.profile:
        context.push('/user/${Uri.encodeComponent(item.deeplinkId)}');
    }
  }
}

class _InboxPushListCallout extends StatelessWidget {
  const _InboxPushListCallout({
    required this.blocked,
    required this.busy,
    required this.onTurnOn,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final bool blocked;
  final bool busy;
  final VoidCallback onTurnOn;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = blocked
        ? l10n.notificationsPushPromptBlockedTitle
        : l10n.notificationsPushPromptListTitle;
    final body = blocked
        ? l10n.notificationsPushPromptBlockedBody
        : l10n.notificationsPushPromptListBody;
    final actionLabel = blocked
        ? l10n.profileNotificationSettingsTitle
        : l10n.notificationsPushPromptTurnOn;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.28),
      shape: const RoundedRectangleBorder(
        borderRadius: _kNotificationRowRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.devices_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : (blocked ? onOpenSettings : onTurnOn),
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.notificationsPushPromptNotNow,
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsLoadingSkeleton extends StatelessWidget {
  const _NotificationsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = scheme.surfaceContainerHighest.withValues(alpha: 0.85);

    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: placeholder,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: 7,
          separatorBuilder: (_, _) =>
              const SizedBox(height: _kNotificationRowSpacing),
          itemBuilder: (context, index) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: _kNotificationRowRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(double.infinity, 14),
                          const SizedBox(height: 8),
                          bar(MediaQuery.sizeOf(context).width * 0.45, 12),
                          const SizedBox(height: 8),
                          bar(120, 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  const _NotificationListTile({
    required this.item,
    required this.timeLabel,
    required this.onOpen,
    required this.onLongPress,
  });

  final UserNotification item;
  final String timeLabel;
  final VoidCallback onOpen;

  /// Read row → mark unread; unread row → mark read (no navigation).
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = localizedUserNotificationCopy(item, l10n);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isUnread = !item.read;

    final titleStyle = (isUnread ? textTheme.titleMedium : textTheme.bodyLarge)
        ?.copyWith(
          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          color: isUnread
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.72),
        );

    final hoverAlpha = isUnread ? 0.05 : 0.07;
    final focusAlpha = 0.14;

    final tile = Material(
      color: isUnread
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
          : Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: _kNotificationRowRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: _kNotificationRowRadius,
        hoverColor: scheme.onSurface.withValues(alpha: hoverAlpha),
        focusColor: scheme.primary.withValues(alpha: focusAlpha),
        highlightColor: scheme.primary.withValues(alpha: 0.08),
        splashColor: scheme.primary.withValues(alpha: 0.10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    switch (item.deeplinkKind) {
                      UserNotificationDeeplinkKind.event =>
                        Icons.event_outlined,
                      UserNotificationDeeplinkKind.spot => Icons.place_outlined,
                      UserNotificationDeeplinkKind.profile =>
                        Icons.person_outline,
                    },
                    color: scheme.primary.withValues(
                      alpha: isUnread ? 1 : 0.65,
                    ),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (copy.body != null && copy.body!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          copy.body!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(
                              alpha: isUnread ? 0.8 : 0.62,
                            ),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        timeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: l10n.notificationsOpenSemantic(copy.title),
        hint: item.read
            ? l10n.notificationsMarkAsUnreadHint
            : l10n.notificationsMarkAsReadHint,
        child: tile,
      ),
    );
  }
}
