import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_sync_source_service.dart';
import '../../utils/search_index_backfill_message.dart';
import '../../utils/event_schedule_utils.dart';

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
    bool? withoutLocationOnly,
  }) async {
    final service = context.read<AdminEventsService>();
    final changed = service.updateListFilters(
      eventSourceFilter: eventSourceFilter,
      upcomingOnly: upcomingOnly,
      excludeDuplicates: excludeDuplicates,
      withoutLocationOnly: withoutLocationOnly,
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
      final result = await eventsService.backfillEventSearchTerms(purge: purgeTerms);
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
              _AdminEventsFilterBar(
                service: service,
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
              ),
              Expanded(child: _buildEventsBody(context, service)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventsBody(BuildContext context, AdminEventsService service) {
          if (service.isLoading && service.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(service.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => service.fetchEvents(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (service.events.isEmpty) {
            final emptyMessage = service.hasActiveListFilters
                ? 'No events match the current filters'
                : 'No events yet';
            return RefreshIndicator(
              onRefresh: () => service.fetchEvents(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 140),
                    child: Column(
                      children: [
                        Icon(
                          service.hasActiveListFilters
                              ? Icons.filter_alt_off_outlined
                              : Icons.event_busy_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(emptyMessage),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final showLoadMore = service.hasMore;
          final itemCount = service.events.length + (showLoadMore ? 1 : 0);

          return RefreshIndicator(
            onRefresh: () => service.fetchEvents(forceRefresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= service.events.length) {
                  return _EventsLoadMoreFooter(service: service);
                }
                return _EventCard(event: service.events[index]);
              },
            ),
          );
  }
}

class _AdminEventsFilterBar extends StatelessWidget {
  const _AdminEventsFilterBar({
    required this.service,
    required this.onEventSourceChanged,
    required this.onUpcomingOnlyChanged,
    required this.onExcludeDuplicatesChanged,
    required this.onWithoutLocationOnlyChanged,
  });

  final AdminEventsService service;
  final ValueChanged<String?>? onEventSourceChanged;
  final ValueChanged<bool>? onUpcomingOnlyChanged;
  final ValueChanged<bool>? onExcludeDuplicatesChanged;
  final ValueChanged<bool>? onWithoutLocationOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Consumer<EventSyncSourceService>(
              builder: (context, sourceService, _) {
                final sources = [...sourceService.sources]
                  ..sort((a, b) => a.name.compareTo(b.name));

                return DropdownButtonFormField<String>(
                  initialValue: service.eventSourceFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Event source',
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: AdminEventsService.eventSourceFilterAll,
                      child: Text('All sources'),
                    ),
                    const DropdownMenuItem<String>(
                      value: AdminEventsService.eventSourceFilterNative,
                      child: Text('Native (parkour.spot)'),
                    ),
                    ...sources.map(
                      (source) => DropdownMenuItem<String>(
                        value: source.id,
                        child: Text(
                          source.isActive
                              ? source.name
                              : '${source.name} (inactive)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onEventSourceChanged,
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Upcoming only'),
                  selected: service.upcomingOnly,
                  onSelected: onUpcomingOnlyChanged == null
                      ? null
                      : (selected) => onUpcomingOnlyChanged!(selected),
                ),
                FilterChip(
                  label: const Text('Exclude duplicates'),
                  selected: service.excludeDuplicates,
                  onSelected: onExcludeDuplicatesChanged == null
                      ? null
                      : (selected) => onExcludeDuplicatesChanged!(selected),
                ),
                FilterChip(
                  label: const Text('Without location only'),
                  selected: service.withoutLocationOnly,
                  onSelected: onWithoutLocationOnlyChanged == null
                      ? null
                      : (selected) => onWithoutLocationOnlyChanged!(selected),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ParkourEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startLabel = _formatScheduleMoment(
      context,
      event.startAt,
      isDateOnly: event.isDateOnly,
      timeZone: event.timeZone,
    );
    final endLabel = event.endAt == null
        ? null
        : _formatScheduleMoment(
            context,
            event.endAt!,
            isDateOnly: event.isDateOnly,
            timeZone: event.timeZone,
          );
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final hasLocation = event.latitude != null && event.longitude != null;
    final sourceName = event.eventSourceName?.trim();
    final hasSource = sourceName != null && sourceName.isNotEmpty;
    final duplicateOfId = event.duplicateOf?.trim();
    final hasDuplicateLink = duplicateOfId != null && duplicateOfId.isNotEmpty;
    final openEventPage = event.id == null
        ? null
        : () => context.push('/event/${event.id}');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openEventPage,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (event.id != null) ...[
                    IconButton(
                      onPressed: () {
                        context.push('/admin/events/${event.id}/edit');
                      },
                      tooltip: 'Edit event',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: openEventPage,
                      tooltip: 'Open event page',
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                ],
              ),
              if (event.description != null &&
                  event.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(event.description!),
                ),
              if (hasDuplicateLink) ...[
                const SizedBox(height: 8),
                _EventDuplicateChip(
                  originalEventId: duplicateOfId,
                  duplicateOfLabel: l10n.spotDetailDuplicateOf,
                  originalTitleFallback: l10n.eventDetailOriginalEventFallback,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(startLabel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (endLabel != null)
                    Chip(
                      avatar: const Icon(Icons.hourglass_bottom, size: 16),
                      label: Text(endLabel),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    label: Text('${event.spotIds.length} linked spot(s)'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Chip(
                    avatar: const Icon(Icons.list, size: 16),
                    label: Text('${event.spotListIds.length} linked list(s)'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (hasSource)
                    Chip(
                      avatar: const Icon(Icons.sync, size: 16),
                      label: Text(sourceName),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              if (hasSource &&
                  (event.externalSyncLastSeenAt != null ||
                      event.externalSyncLastChangedAt != null)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (event.externalSyncLastSeenAt != null)
                      Chip(
                        avatar: const Icon(Icons.update, size: 16),
                        label: Text(
                          'Seen: ${_formatUtc(context, event.externalSyncLastSeenAt!)}',
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (event.externalSyncLastChangedAt != null)
                      Chip(
                        avatar: const Icon(Icons.edit_calendar, size: 16),
                        label: Text(
                          'Changed: ${_formatUtc(context, event.externalSyncLastChangedAt!)}',
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SelectableText(
                'Spot IDs: ${event.spotIds.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (event.spotListIds.isNotEmpty)
                SelectableText(
                  'List IDs: ${event.spotListIds.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (event.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: event.imageUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          event.imageUrls[index],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 72,
                            height: 72,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (hasWebsite) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openWebsite(websiteUrl),
                  child: Text(
                    websiteUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              if (hasLocation) ...[
                const SizedBox(height: 10),
                Text(
                  event.address?.trim().isNotEmpty == true
                      ? event.address!
                      : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (event.id != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: openEventPage,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open event page'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatScheduleMoment(
    BuildContext context,
    DateTime value, {
    required bool isDateOnly,
    String? timeZone,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final display = EventScheduleUtils.toDisplayDateTime(
      value,
      timeZone: timeZone,
    );
    final date = localizations.formatMediumDate(display);
    if (isDateOnly) return date;
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(display));
    final normalizedTimeZone = EventScheduleUtils.normalizeTimeZone(timeZone);
    final suffix = normalizedTimeZone == null ? '' : ' ${display.timeZoneName}';
    return '$date · $time$suffix';
  }

  String _formatUtc(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final utc = value.toUtc();
    final date = localizations.formatMediumDate(utc);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(utc),
      alwaysUse24HourFormat: true,
    );
    return '$date $time UTC';
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _EventDuplicateChip extends StatefulWidget {
  const _EventDuplicateChip({
    required this.originalEventId,
    required this.duplicateOfLabel,
    required this.originalTitleFallback,
  });

  final String originalEventId;
  final String duplicateOfLabel;
  final String originalTitleFallback;

  @override
  State<_EventDuplicateChip> createState() => _EventDuplicateChipState();
}

class _EventDuplicateChipState extends State<_EventDuplicateChip> {
  String? _originalTitle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOriginalTitle();
  }

  @override
  void didUpdateWidget(covariant _EventDuplicateChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalEventId != widget.originalEventId) {
      setState(() {
        _originalTitle = null;
        _loading = true;
      });
      _loadOriginalTitle();
    }
  }

  Future<void> _loadOriginalTitle() async {
    final original = await context.read<AdminEventsService>().getEventById(
      widget.originalEventId,
    );
    if (!mounted) return;
    setState(() {
      _originalTitle = original?.title.trim();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _loading
        ? '…'
        : ((_originalTitle != null && _originalTitle!.isNotEmpty)
              ? _originalTitle!
              : widget.originalTitleFallback);

    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/event/${widget.originalEventId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.copy_all,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.duplicateOfLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsLoadMoreFooter extends StatelessWidget {
  const _EventsLoadMoreFooter({required this.service});

  final AdminEventsService service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: service.isLoadingMore
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.icon(
                onPressed: () => service.loadMore(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
      ),
    );
  }
}
