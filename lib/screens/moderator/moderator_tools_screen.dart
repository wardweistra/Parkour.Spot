import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/event_report_service.dart';
import '../../services/spot_report_service.dart';
import '../../widgets/page_scaffold.dart';

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
        title: 'Moderator Tools',
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
        title: 'Moderator Tools',
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
        title: 'Moderator Tools',
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
      title: 'Moderator Tools',
      scrollable: false,
      onBack: () => _handleBack(context),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          StreamBuilder<int>(
            initialData: context.read<SpotReportService>().newReportCount,
            stream: context.read<SpotReportService>().watchNewReportCount(),
            builder: (context, snapshot) {
              final newCount = snapshot.data ?? 0;
              return _buildQueueTile(
                icon: Icons.report_problem,
                title: 'Spot Report Queue',
                subtitle:
                    'Work through new spot reports, keeping moderators aligned on progress',
                badgeCount: newCount > 0 ? newCount : null,
                onTap: () => context.go('/moderator/reports'),
              );
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            initialData: context.read<EventReportService>().newReportCount,
            stream: context.read<EventReportService>().watchNewReportCount(),
            builder: (context, snapshot) {
              final newCount = snapshot.data ?? 0;
              return _buildQueueTile(
                icon: Icons.event_note_outlined,
                title: 'Event Report Queue',
                subtitle:
                    'Review user-submitted event proposals and publish approved events',
                badgeCount: newCount > 0 ? newCount : null,
                onTap: () => context.go('/moderator/event-reports'),
              );
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<int>(
            initialData: context.read<AdminEventsService>().needsReviewCount,
            stream: context.read<AdminEventsService>().watchNeedsReviewCount(),
            builder: (context, snapshot) {
              final reviewCount = snapshot.data ?? 0;
              return _buildQueueTile(
                icon: Icons.event_available_outlined,
                title: 'Event Review',
                subtitle:
                    'Review newly synced events for duplicates and location quality',
                badgeCount: reviewCount > 0 ? reviewCount : null,
                onTap: () => context.go('/moderator/events'),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Duplicate Spot Detection'),
              subtitle: const Text(
                'Find potential duplicate spots within 50m from different sources',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.go('/moderator/duplicate-spots'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    Widget leading = Icon(icon);
    if (badgeCount != null && badgeCount > 0) {
      leading = Badge(
        label: Text('$badgeCount'),
        child: leading,
      );
    }
    return Card(
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
