import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/parkour_event.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_sync_source_service.dart';
import '../../widgets/events_overview.dart';
import '../../widgets/page_scaffold.dart';

class ModeratorEventsReviewScreen extends StatefulWidget {
  const ModeratorEventsReviewScreen({super.key});

  @override
  State<ModeratorEventsReviewScreen> createState() =>
      _ModeratorEventsReviewScreenState();
}

class _ModeratorEventsReviewScreenState
    extends State<ModeratorEventsReviewScreen> {
  late final AuthService _authService;
  late final AdminEventsService _eventsService;
  bool _scheduledInitialFetch = false;
  bool _restoredFiltersOnDispose = false;

  ({
    String eventSourceFilter,
    bool upcomingOnly,
    bool excludeDuplicates,
    bool withoutLocationOnly,
    bool needsModeratorReviewOnly,
  })?
  _savedFilters;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _eventsService = context.read<AdminEventsService>();
    _authService.addListener(_tryFetchForModerator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyModeratorDefaults();
      _tryFetchForModerator();
      _loadEventSources();
    });
  }

  void _applyModeratorDefaults() {
    _savedFilters = (
      eventSourceFilter: _eventsService.eventSourceFilter,
      upcomingOnly: _eventsService.upcomingOnly,
      excludeDuplicates: _eventsService.excludeDuplicates,
      withoutLocationOnly: _eventsService.withoutLocationOnly,
      needsModeratorReviewOnly: _eventsService.needsModeratorReviewOnly,
    );
    _eventsService.updateListFilters(
      eventSourceFilter: AdminEventsService.eventSourceFilterAll,
      upcomingOnly: true,
      excludeDuplicates: true,
      withoutLocationOnly: false,
      needsModeratorReviewOnly: true,
    );
  }

  void _restoreSavedFilters() {
    if (_restoredFiltersOnDispose || _savedFilters == null) return;
    _restoredFiltersOnDispose = true;
    final saved = _savedFilters!;
    _eventsService.updateListFilters(
      eventSourceFilter: saved.eventSourceFilter,
      upcomingOnly: saved.upcomingOnly,
      excludeDuplicates: saved.excludeDuplicates,
      withoutLocationOnly: saved.withoutLocationOnly,
      needsModeratorReviewOnly: saved.needsModeratorReviewOnly,
    );
  }

  Future<void> _loadEventSources() async {
    await context.read<EventSyncSourceService>().fetchSources(
      includeInactive: true,
    );
  }

  Future<void> _onFiltersChanged({
    String? eventSourceFilter,
    bool? upcomingOnly,
    bool? excludeDuplicates,
    bool? withoutLocationOnly,
    bool? needsModeratorReviewOnly,
  }) async {
    final service = context.read<AdminEventsService>();
    final changed = service.updateListFilters(
      eventSourceFilter: eventSourceFilter,
      upcomingOnly: upcomingOnly,
      excludeDuplicates: excludeDuplicates,
      withoutLocationOnly: withoutLocationOnly,
      needsModeratorReviewOnly: needsModeratorReviewOnly,
    );
    if (!changed) return;

    _scheduledInitialFetch = true;
    await service.fetchEvents(forceRefresh: true);
  }

  @override
  void dispose() {
    _authService.removeListener(_tryFetchForModerator);
    _restoreSavedFilters();
    super.dispose();
  }

  void _tryFetchForModerator() {
    if (!mounted) return;
    final hasAccess = _authService.isModerator || _authService.isAdmin;
    if (!hasAccess || !_authService.isProfileReady) return;
    if (_scheduledInitialFetch) return;

    final service = context.read<AdminEventsService>();
    if (service.events.isNotEmpty || service.isLoading) return;

    _scheduledInitialFetch = true;
    service.fetchEvents(forceRefresh: true);
  }

  Future<void> _markReviewed(ParkourEvent event) async {
    final eventId = event.id;
    if (eventId == null) return;

    final service = context.read<AdminEventsService>();
    final success = await service.clearModeratorReviewFlag(eventId);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Marked "${event.title}" as reviewed'),
          backgroundColor: Colors.green,
        ),
      );
      if (service.needsModeratorReviewOnly) {
        await service.fetchEvents(forceRefresh: true);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(service.error ?? 'Failed to mark event as reviewed'),
        ),
      );
    }
  }

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/moderator');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (!authService.isAuthenticated) {
      return PageScaffold(
        title: 'Event Review',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Sign in required')),
      );
    }

    if (authService.isLoading) {
      return PageScaffold(
        title: 'Event Review',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return PageScaffold(
        title: 'Event Review',
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Moderator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        actions: [
          Consumer<AdminEventsService>(
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
                    : () => service.fetchEvents(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: Consumer<AdminEventsService>(
        builder: (context, service, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review checklist',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check whether the event is a duplicate of another event, '
                        'and whether the location is set and specific enough '
                        '(can it be linked to a spot?).',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              EventsOverviewFilterBar(
                service: service,
                showNeedsModeratorReviewFilter: true,
                onEventSourceChanged: service.isLoading
                    ? null
                    : (value) => _onFiltersChanged(eventSourceFilter: value),
                onUpcomingOnlyChanged: service.isLoading
                    ? null
                    : (value) => _onFiltersChanged(upcomingOnly: value),
                onExcludeDuplicatesChanged: service.isLoading
                    ? null
                    : (value) => _onFiltersChanged(excludeDuplicates: value),
                onWithoutLocationOnlyChanged: service.isLoading
                    ? null
                    : (value) =>
                          _onFiltersChanged(withoutLocationOnly: value),
                onNeedsModeratorReviewOnlyChanged: service.isLoading
                    ? null
                    : (value) =>
                          _onFiltersChanged(needsModeratorReviewOnly: value),
              ),
              Expanded(
                child: EventsOverviewBody(
                  service: service,
                  showModeratorReviewActions: true,
                  onMarkReviewed: _markReviewed,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
