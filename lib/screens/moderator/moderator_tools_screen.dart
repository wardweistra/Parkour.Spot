import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/event_report_service.dart';
import '../../services/spot_report_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';
import '../admin/admin_tool_widgets.dart';

class ModeratorToolsScreen extends StatelessWidget {
  const ModeratorToolsScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/explore?tab=profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (!authService.isAuthenticated) {
      return PageScaffold(
        title: 'Moderator tools',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Sign in required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Moderator tools are available after signing in.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(
                    '/login?redirectTo=${Uri.encodeComponent('/moderator')}',
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (authService.isLoading) {
      return PageScaffold(
        title: 'Moderator tools',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading your profile…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return PageScaffold(
        title: 'Moderator tools',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Moderator access required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask an administrator to grant you moderator permissions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PageScaffold(
      title: 'Moderator tools',
      scrollable: false,
      onBack: () => _handleBack(context),
      body: ListView(
        children: [
          const AdminSectionHeader(title: 'Spots'),
          AdminSectionCard(
            children: [
              StreamBuilder<int>(
                initialData: context.read<SpotReportService>().newReportCount,
                stream: context.read<SpotReportService>().watchNewReportCount(),
                builder: (context, snapshot) {
                  final newCount = snapshot.data ?? 0;
                  return AdminToolTile(
                    icon: Icons.report_problem,
                    title: 'Spot report queue',
                    subtitle:
                        'Work through new spot reports, keeping moderators aligned on progress',
                    badgeCount: newCount > 0 ? newCount : null,
                    onTap: () => context.go('/moderator/reports'),
                  );
                },
              ),
              AdminToolTile(
                icon: Icons.compare_arrows,
                title: 'Duplicate spot detection',
                subtitle:
                    'Find potential duplicate spots within 50m from different sources',
                onTap: () => context.go('/moderator/duplicate-spots'),
              ),
              StreamBuilder<int>(
                initialData: context
                    .read<SpotService>()
                    .duplicatePendingChangesCount,
                stream: context
                    .read<SpotService>()
                    .watchDuplicatePendingChangesCount(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  final l10n = AppLocalizations.of(context)!;
                  return AdminToolTile(
                    icon: Icons.copy_all_outlined,
                    title: l10n.spotDuplicateChangesQueueTitle,
                    subtitle: l10n.spotDuplicateChangesQueueSubtitle,
                    badgeCount: pendingCount > 0 ? pendingCount : null,
                    onTap: () =>
                        context.go('/moderator/duplicate-spot-updates'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Events'),
          AdminSectionCard(
            children: [
              StreamBuilder<int>(
                initialData: context.read<EventReportService>().newReportCount,
                stream: context
                    .read<EventReportService>()
                    .watchNewReportCount(),
                builder: (context, snapshot) {
                  final newCount = snapshot.data ?? 0;
                  return AdminToolTile(
                    icon: Icons.event_note_outlined,
                    title: 'Event report queue',
                    subtitle:
                        'Review user-submitted event proposals and publish approved events',
                    badgeCount: newCount > 0 ? newCount : null,
                    onTap: () => context.go('/moderator/event-reports'),
                  );
                },
              ),
              StreamBuilder<int>(
                initialData: context
                    .read<AdminEventsService>()
                    .needsReviewCount,
                stream: context
                    .read<AdminEventsService>()
                    .watchNeedsReviewCount(),
                builder: (context, snapshot) {
                  final reviewCount = snapshot.data ?? 0;
                  return AdminToolTile(
                    icon: Icons.event_available_outlined,
                    title: 'Event review',
                    subtitle:
                        'Review newly synced events for duplicates and location quality',
                    badgeCount: reviewCount > 0 ? reviewCount : null,
                    onTap: () => context.go('/moderator/events'),
                  );
                },
              ),
              StreamBuilder<int>(
                initialData: context
                    .read<AdminEventsService>()
                    .duplicatePendingChangesCount,
                stream: context
                    .read<AdminEventsService>()
                    .watchDuplicatePendingChangesCount(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  final l10n = AppLocalizations.of(context)!;
                  return AdminToolTile(
                    icon: Icons.copy_all_outlined,
                    title: l10n.eventDuplicateChangesQueueTitle,
                    subtitle: l10n.eventDuplicateChangesQueueSubtitle,
                    badgeCount: pendingCount > 0 ? pendingCount : null,
                    onTap: () =>
                        context.go('/moderator/duplicate-event-updates'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
