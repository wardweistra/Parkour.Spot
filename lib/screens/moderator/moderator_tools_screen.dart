import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.report_problem),
              title: const Text('Spot Report Queue'),
              subtitle: const Text(
                'Work through new spot reports, keeping moderators aligned on progress',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push('/moderator/reports'),
            ),
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
              onTap: () => context.push('/moderator/duplicate-spots'),
            ),
          ),
        ],
      ),
    );
  }
}
