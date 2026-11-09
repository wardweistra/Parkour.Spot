import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/my_activities_calendar_section.dart';
import '../../widgets/page_scaffold.dart';

/// Hub for events, sessions, and calendar sync under Account.
class MyActivitiesHubScreen extends StatelessWidget {
  const MyActivitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final l10n = AppLocalizations.of(context)!;
        if (!authService.isAuthenticated) {
          return PageScaffold(
            title: l10n.myActivitiesTitle,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.dynamic_feed_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    l10n.myActivitiesHubSignInPrompt,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent('/profile/activities')}',
                    ),
                    child: Text(l10n.profileSignInButton),
                  ),
                ],
              ),
            ),
          );
        }

        return PageScaffold(
          title: l10n.myActivitiesTitle,
          scrollable: false,
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const MyActivitiesCalendarSection(),
              const SizedBox(height: 8),
              _HubDestinationRow(
                icon: Icons.event_outlined,
                title: l10n.myEventsTitle,
                subtitle: l10n.accountMyEventsSubtitle,
                onTap: () => context.push('/profile/events'),
              ),
              _HubDestinationRow(
                icon: Icons.how_to_reg_outlined,
                title: l10n.mySessionsTitle,
                subtitle: l10n.publicProfileMyCheckInsSubtitle,
                onTap: () => context.push('/profile/check-ins'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HubDestinationRow extends StatelessWidget {
  const _HubDestinationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
