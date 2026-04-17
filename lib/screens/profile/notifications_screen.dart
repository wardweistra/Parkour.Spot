import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user_notification.dart';
import '../../services/user_notification_service.dart';
import '../../utils/user_notification_localization.dart';
import '../../widgets/page_scaffold.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationService = context.watch<UserNotificationService>();

    return PageScaffold(
      title: l10n.notificationsTitle,
      // ListView must not live inside PageScaffold's default SingleChildScrollView
      // (unbounded height on web). The list scrolls itself.
      scrollable: false,
      centerContent: false,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/explore?tab=profile');
        }
      },
      body: StreamBuilder<List<UserNotification>>(
        stream: notificationService.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final err = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <UserNotification>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                  ],
                ),
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _NotificationListTile(
                    item: item,
                    timeLabel: _formatTimestamp(context, item.createdAt, l10n),
                    onOpen: () => _openNotification(context, item),
                  );
                },
              ),
            ),
          );
        },
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

  static Future<void> _openNotification(
    BuildContext context,
    UserNotification item,
  ) async {
    final notificationService = context.read<UserNotificationService>();

    if (!item.read) {
      await notificationService.markAsRead(item.id);
    }
    if (!context.mounted) return;

    switch (item.deeplinkKind) {
      case UserNotificationDeeplinkKind.spot:
        if (item.deeplinkId.isEmpty) return;
        context.push('/spot/${item.deeplinkId}');
      case UserNotificationDeeplinkKind.profile:
        if (item.deeplinkId.isEmpty) return;
        context.push('/user/${Uri.encodeComponent(item.deeplinkId)}');
    }
  }
}

class _NotificationListTile extends StatelessWidget {
  const _NotificationListTile({
    required this.item,
    required this.timeLabel,
    required this.onOpen,
  });

  final UserNotification item;
  final String timeLabel;
  final VoidCallback onOpen;

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

    final tile = Material(
      color: isUnread
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
          : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.deeplinkKind == UserNotificationDeeplinkKind.spot
                      ? Icons.place_outlined
                      : Icons.person_outline,
                  color: scheme.primary.withValues(alpha: isUnread ? 1 : 0.65),
                  size: 24,
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
        child: tile,
      ),
    );
  }
}
