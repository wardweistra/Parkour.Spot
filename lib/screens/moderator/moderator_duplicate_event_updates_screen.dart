import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/event_duplicate_changes_dialog.dart';
import '../../widgets/events_overview.dart';
import '../../widgets/page_scaffold.dart';

class ModeratorDuplicateEventUpdatesScreen extends StatelessWidget {
  const ModeratorDuplicateEventUpdatesScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/moderator');
    }
  }

  Future<void> _review(BuildContext context, ParkourEvent event) async {
    await reviewEventDuplicateChanges(context: context, duplicateEvent: event);
  }

  Future<void> _dismiss(BuildContext context, ParkourEvent event) async {
    await reviewEventDuplicateChanges(
      context: context,
      duplicateEvent: event,
      dismissWithoutDialog: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context)!;

    if (!authService.isAuthenticated) {
      return PageScaffold(
        title: l10n.eventDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Sign in required')),
      );
    }

    if (authService.isLoading) {
      return PageScaffold(
        title: l10n.eventDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return PageScaffold(
        title: l10n.eventDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Moderator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.eventDuplicateChangesQueueTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: StreamBuilder<List<ParkourEvent>>(
        stream: context
            .read<AdminEventsService>()
            .watchDuplicatePendingChangeEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_all_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.eventDuplicateChangesQueueEmpty),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final event = events[index];
              return EventsOverviewCard(
                event: event,
                showDuplicatePendingActions: true,
                onReviewDuplicateChanges: () => _review(context, event),
                onDismissDuplicateChanges: () => _dismiss(context, event),
              );
            },
          );
        },
      ),
    );
  }
}
