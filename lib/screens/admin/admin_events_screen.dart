import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_sync_source_service.dart';
import '../../utils/search_index_backfill_message.dart';
import '../../widgets/events_overview.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late final AuthService _authService;
  bool _scheduledInitialFetch = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _authService.addListener(_tryFetchForAdmin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryFetchForAdmin();
      _loadEventSources();
    });
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
    bool? excludeHidden,
    bool? withoutLocationOnly,
    bool? needsModeratorReviewOnly,
  }) async {
    final service = context.read<AdminEventsService>();
    final changed = service.updateListFilters(
      eventSourceFilter: eventSourceFilter,
      upcomingOnly: upcomingOnly,
      excludeDuplicates: excludeDuplicates,
      excludeHidden: excludeHidden,
      withoutLocationOnly: withoutLocationOnly,
      needsModeratorReviewOnly: needsModeratorReviewOnly,
    );
    if (!changed) return;

    _scheduledInitialFetch = true;
    await service.fetchEvents(forceRefresh: true);
  }

  @override
  void dispose() {
    _authService.removeListener(_tryFetchForAdmin);
    super.dispose();
  }

  void _tryFetchForAdmin() {
    if (!mounted) return;
    if (!_authService.isAdmin || !_authService.isProfileReady) return;
    if (_scheduledInitialFetch) return;

    final service = context.read<AdminEventsService>();
    if (service.events.isNotEmpty || service.isLoading) return;

    _scheduledInitialFetch = true;
    service.fetchEvents();
  }

  Future<void> _showBackfillEventMapPinsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backfill Event Map Pins'),
          content: const Text(
            'Materializes eventMapPins for map display from each event\'s '
            'linked spots and spot lists. This may take several minutes for '
            'large databases.\n\n'
            'Backfill all events or select one event?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _runBackfillEventMapPins();
              },
              child: const Text('All Events'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showBackfillEventSelectionDialog();
              },
              child: const Text('Select Event'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackfillEventSelectionDialog() async {
    final eventsService = context.read<AdminEventsService>();
    final events = [...eventsService.events]
      ..sort((a, b) => a.title.compareTo(b.title));

    if (events.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events loaded to select from')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Event'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: events.length,
              itemBuilder: (_, index) {
                final event = events[index];
                final id = event.id;
                if (id == null) return const SizedBox.shrink();
                return ListTile(
                  title: Text(event.title),
                  subtitle: Text(id),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _runBackfillEventMapPins(eventId: id);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _backfillEventSearchTerms() async {
    var purgeTerms = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Backfill Event Name Search'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Populates eventSearchTerms for upcoming events (Explore autocomplete). '
                'This may take a few minutes for large databases.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: purgeTerms,
                onChanged: (v) => setState(() => purgeTerms = v ?? false),
                title: const Text('Purge existing terms first'),
                subtitle: const Text(
                  'Deletes all eventSearchTerms, then rebuilds only for events '
                  'shown on the map (not duplicates or past).',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    final eventsService = context.read<AdminEventsService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    late NavigatorState progressNavigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressNavigator = Navigator.of(dialogContext);
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Backfilling eventSearchTerms...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await eventsService.backfillEventSearchTerms(
        purge: purgeTerms,
      );
      progressNavigator.pop();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final stats = result['stats'] as Map<String, dynamic>?;
        final msg = stats != null
            ? formatSearchIndexBackfillMessage(
                entityLabel: 'Events',
                totalProcessed: stats['totalProcessed'],
                searchTermsWritten: stats['searchTermsWritten'],
                searchTermsDeleted: stats['searchTermsDeleted'],
                purged: stats['purged'] == true,
              )
            : 'Backfill completed';
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              eventsService.error ?? 'Event search terms backfill failed',
            ),
          ),
        );
      }
    } catch (e) {
      progressNavigator.pop();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Event search terms backfill failed: $e'),
        ),
      );
    }
  }

  Future<void> _runBackfillEventMapPins({String? eventId}) async {
    final eventsService = context.read<AdminEventsService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    late NavigatorState progressNavigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        progressNavigator = Navigator.of(dialogContext);
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  eventId == null
                      ? 'Backfilling map pins for all events...'
                      : 'Backfilling map pins for event...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final result = await eventsService.backfillEventMapPins(eventId: eventId);
      progressNavigator.pop();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final processed = result['processed'] ?? 0;
        final pinsWritten = result['pinsWritten'] ?? 0;
        final truncatedCount = result['truncatedCount'] ?? 0;
        final truncatedNote = truncatedCount > 0
            ? ', $truncatedCount truncated'
            : '';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Map pins backfill complete. Events: $processed, '
              'pins written: $pinsWritten$truncatedNote',
            ),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              eventsService.error ?? 'Event map pins backfill failed',
            ),
          ),
        );
      }
    } catch (e) {
      progressNavigator.pop();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Event map pins backfill failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Events')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
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
          IconButton(
            tooltip: 'Backfill event name search (eventSearchTerms)',
            icon: const Icon(Icons.search),
            onPressed: _backfillEventSearchTerms,
          ),
          IconButton(
            tooltip: 'Backfill event map pins',
            icon: const Icon(Icons.map_outlined),
            onPressed: _showBackfillEventMapPinsDialog,
          ),
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
                onExcludeHiddenChanged: service.isLoading
                    ? null
                    : (value) => _onFiltersChanged(excludeHidden: value),
                onWithoutLocationOnlyChanged: service.isLoading
                    ? null
                    : (value) => _onFiltersChanged(withoutLocationOnly: value),
                onNeedsModeratorReviewOnlyChanged: service.isLoading
                    ? null
                    : (value) =>
                          _onFiltersChanged(needsModeratorReviewOnly: value),
              ),
              Expanded(
                child: EventsOverviewBody(
                  service: service,
                  showAdminEditAction: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
