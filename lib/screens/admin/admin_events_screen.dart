import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_sync_source_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../utils/browser_timezone_utils.dart';
import '../../utils/search_index_backfill_message.dart';
import '../../utils/event_schedule_utils.dart';
import '../../utils/image_preparation.dart';
import '../../widgets/spot_list_selection_dialog.dart';
import '../../widgets/spot_selection_dialog.dart';

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

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateEventDialog(
        onCreate:
            ({
              required String title,
              String? description,
              List<String>? imageUrls,
              String? websiteUrl,
              required DateTime startAt,
              DateTime? endAt,
              required bool isDateOnly,
              String? timeZone,
              double? latitude,
              double? longitude,
              String? address,
              String? city,
              String? countryCode,
              required List<String> spotIds,
              List<String> spotListIds = const <String>[],
            }) async {
              final authService = context.read<AuthService>();
              final createdBy = authService.currentUser?.uid ?? 'unknown';
              return context.read<AdminEventsService>().createEvent(
                title: title,
                description: description,
                imageUrls: imageUrls,
                websiteUrl: websiteUrl,
                startAt: startAt,
                endAt: endAt,
                isDateOnly: isDateOnly,
                timeZone: timeZone,
                latitude: latitude,
                longitude: longitude,
                address: address,
                city: city,
                countryCode: countryCode,
                spotIds: spotIds,
                spotListIds: spotListIds,
                createdBy: createdBy,
              );
            },
      ),
    );

    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(created ? 'Event created' : 'Failed to create event'),
        backgroundColor: created ? Colors.green : Colors.red,
      ),
    );
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
          IconButton(
            tooltip: 'Add event',
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
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

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.onCreate});

  final Future<bool> Function({
    required String title,
    String? description,
    List<String>? imageUrls,
    String? websiteUrl,
    required DateTime startAt,
    DateTime? endAt,
    required bool isDateOnly,
    String? timeZone,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    required List<String> spotIds,
    List<String> spotListIds,
  })
  onCreate;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  static const String _localTimeZoneValue = '__local__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _newImageUrlController = TextEditingController();

  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;
  bool _isDateOnly = false;
  late String _selectedTimeZone;
  late final List<String> _timeZoneOptions;
  bool _isSubmitting = false;
  bool _isGeocoding = false;
  String? _formError;
  String? _currentCity;
  String? _currentCountryCode;
  final List<Spot> _linkedSpots = <Spot>[];
  final List<SpotList> _linkedLists = <SpotList>[];
  final List<Uint8List> _selectedImageBytes = <Uint8List>[];
  final List<String> _imageUrls = <String>[];

  @override
  void initState() {
    super.initState();
    _selectedTimeZone = detectIanaTimeZone();
    _timeZoneOptions = <String>[
      _localTimeZoneValue,
      ...EventScheduleUtils.availableTimeZoneIds(),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  String? get _effectiveTimeZone {
    if (_selectedTimeZone == _localTimeZoneValue) return null;
    return EventScheduleUtils.normalizeTimeZone(_selectedTimeZone);
  }

  DateTime _displayInSelectedTimeZone(DateTime value) {
    return EventScheduleUtils.toDisplayDateTime(
      value,
      timeZone: _effectiveTimeZone,
    );
  }

  String _timeZoneLabel(String value) {
    if (value == _localTimeZoneValue) {
      return 'Viewer local timezone (legacy)';
    }
    return EventScheduleUtils.formatTimeZoneLabel(
      value,
      referenceUtc: _startAt,
    );
  }

  Future<void> _pickStartAt() async {
    if (_isDateOnly) {
      final initialDate = _displayInSelectedTimeZone(_startAt);
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (selectedDate == null) return;
      final value = EventScheduleUtils.dateStartToUtc(
        selectedDate,
        timeZone: _effectiveTimeZone,
      );
      setState(() {
        _startAt = value;
        if (_endAt != null && _endAt!.isBefore(_startAt)) {
          _endAt = null;
        }
      });
      return;
    }
    final value = await _pickDateTime(
      context,
      initial: _startAt,
      timeZone: _effectiveTimeZone,
    );
    if (value == null) return;
    setState(() {
      _startAt = value.toUtc();
      if (_endAt != null && _endAt!.isBefore(_startAt)) {
        _endAt = null;
      }
    });
  }

  Future<void> _pickEndAt() async {
    if (_isDateOnly) {
      final initialDateTime = _displayInSelectedTimeZone(_endAt ?? _startAt);
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime(
          initialDateTime.year,
          initialDateTime.month,
          initialDateTime.day,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (selectedDate == null) return;
      setState(
        () => _endAt = EventScheduleUtils.dateEndToUtc(
          selectedDate,
          timeZone: _effectiveTimeZone,
        ),
      );
      return;
    }
    final initial = _endAt ?? _startAt.add(const Duration(hours: 2));
    final value = await _pickDateTime(
      context,
      initial: initial,
      timeZone: _effectiveTimeZone,
    );
    if (value == null) return;
    setState(() {
      _endAt = value.toUtc();
    });
  }

  Future<void> _addLinkedSpot() async {
    final selectedSpotId = await showDialog<String>(
      context: context,
      builder: (_) => const SpotSelectionDialog(allowExternalSources: true),
    );
    if (selectedSpotId == null || !mounted) return;
    if (_linkedSpots.any((spot) => spot.id == selectedSpotId)) return;

    final spotService = context.read<SpotService>();
    final spot = await spotService.getSpotById(selectedSpotId);
    if (!mounted) return;
    if (spot == null || spot.id == null) {
      setState(() {
        _formError = 'Could not load the selected spot';
      });
      return;
    }

    setState(() {
      _linkedSpots.add(spot);
      _formError = null;
    });
  }

  Future<void> _addLinkedList() async {
    final selectedListId = await showDialog<String>(
      context: context,
      builder: (_) => const SpotListSelectionDialog(),
    );
    if (selectedListId == null || !mounted) return;
    if (_linkedLists.any((list) => list.id == selectedListId)) return;

    final spotListService = context.read<SpotListService>();
    final list = await spotListService.getSpotListById(selectedListId);
    if (!mounted) return;
    if (list == null || list.id == null) {
      setState(() {
        _formError = 'Could not load the selected spot list';
      });
      return;
    }

    setState(() {
      _linkedLists.add(list);
      _formError = null;
    });
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty) return;

      var addedCount = 0;
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        _selectedImageBytes.add(prepared.bytes);
        addedCount++;
      }

      if (!mounted || addedCount == 0) return;
      setState(() {
        _formError = null;
      });
    } on ImagePreparationException catch (e) {
      setState(() {
        _formError = e.message;
      });
    } catch (e) {
      setState(() {
        _formError = 'Failed to pick images: $e';
      });
    }
  }

  void _removeSelectedImageAt(int index) {
    setState(() {
      _selectedImageBytes.removeAt(index);
    });
  }

  void _addImageUrl() {
    final value = _newImageUrlController.text.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!valid) {
      setState(() {
        _formError = 'Image URL must be a valid http(s) link';
      });
      return;
    }
    if (_imageUrls.contains(value)) {
      _newImageUrlController.clear();
      return;
    }
    setState(() {
      _imageUrls.add(value);
      _newImageUrlController.clear();
      _formError = null;
    });
  }

  void _removeImageUrlAt(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Future<bool> _tryGeocodeCoordinatesIfNeeded({bool force = false}) async {
    final latRaw = _latitudeController.text.trim();
    final lngRaw = _longitudeController.text.trim();
    final hasLatitudeText = latRaw.isNotEmpty;
    final hasLongitudeText = lngRaw.isNotEmpty;
    final hasAddress = _addressController.text.trim().isNotEmpty;
    final shouldRequireGeocodeSuccess = force || !hasAddress;

    if (!hasLatitudeText && !hasLongitudeText) {
      _currentCity = null;
      _currentCountryCode = null;
      return true;
    }
    if (hasLatitudeText != hasLongitudeText) {
      setState(() {
        _formError = 'Both latitude and longitude are required';
      });
      return false;
    }
    final latitude = double.tryParse(latRaw);
    final longitude = double.tryParse(lngRaw);
    if (latitude == null || longitude == null) {
      setState(() {
        _formError = 'Latitude and longitude must be valid numbers';
      });
      return false;
    }
    if (latitude < -90 || latitude > 90) {
      setState(() {
        _formError = 'Latitude must be between -90 and 90';
      });
      return false;
    }
    if (longitude < -180 || longitude > 180) {
      setState(() {
        _formError = 'Longitude must be between -180 and 180';
      });
      return false;
    }
    final hasCity = _currentCity?.trim().isNotEmpty == true;
    final hasCountryCode = _currentCountryCode?.trim().isNotEmpty == true;
    if (hasAddress && hasCity && hasCountryCode && !force) {
      return true;
    }

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final geocoding = context.read<GeocodingService>();
      final details = await geocoding.geocodeCoordinatesDetails(
        latitude,
        longitude,
      );
      final resolvedAddress = details['address']?.trim();
      final resolvedCity = details['city']?.trim();
      final resolvedCountryCode = details['countryCode']?.trim().toUpperCase();
      if (!mounted) return false;

      if (force) {
        if (resolvedAddress == null || resolvedAddress.isEmpty) {
          setState(() {
            _formError = 'Unable to geocode these coordinates';
          });
          return false;
        }
        setState(() {
          _addressController.text = resolvedAddress;
          _currentCity = resolvedCity?.isNotEmpty == true ? resolvedCity : null;
          _currentCountryCode = resolvedCountryCode?.isNotEmpty == true
              ? resolvedCountryCode
              : null;
          _formError = null;
        });
        return true;
      }

      if (hasAddress) {
        setState(() {
          if (resolvedCity?.isNotEmpty == true && !hasCity) {
            _currentCity = resolvedCity;
          }
          if (resolvedCountryCode?.isNotEmpty == true && !hasCountryCode) {
            _currentCountryCode = resolvedCountryCode;
          }
          _formError = null;
        });
        return true;
      }

      if (resolvedAddress == null || resolvedAddress.isEmpty) {
        if (!shouldRequireGeocodeSuccess) {
          return true;
        }
        setState(() {
          _formError = 'Unable to geocode these coordinates';
        });
        return false;
      }
      setState(() {
        _addressController.text = resolvedAddress;
        _currentCity = resolvedCity?.isNotEmpty == true ? resolvedCity : null;
        _currentCountryCode = resolvedCountryCode?.isNotEmpty == true
            ? resolvedCountryCode
            : null;
        _formError = null;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (!shouldRequireGeocodeSuccess) {
        return true;
      }
      setState(() {
        _formError = 'Failed to geocode coordinates: $e';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final eventsService = context.read<AdminEventsService>();
    if (!_formKey.currentState!.validate()) return;
    final timeZone = _effectiveTimeZone;
    DateTime normalizedStartAt = _startAt;
    DateTime? normalizedEndAt = _endAt;
    if (_isDateOnly) {
      final startDate = _displayInSelectedTimeZone(_startAt);
      normalizedStartAt = EventScheduleUtils.dateStartToUtc(
        startDate,
        timeZone: timeZone,
      );
      final endDate = _displayInSelectedTimeZone(_endAt ?? _startAt);
      normalizedEndAt = EventScheduleUtils.dateEndToUtc(
        endDate,
        timeZone: timeZone,
      );
    }
    if (normalizedEndAt != null &&
        normalizedEndAt.isBefore(normalizedStartAt)) {
      setState(() {
        _formError = 'End time cannot be before start time';
      });
      return;
    }

    final geocoded = await _tryGeocodeCoordinatesIfNeeded();
    if (!geocoded) return;

    List<String> uploadedImageUrls = <String>[];

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      if (_selectedImageBytes.isNotEmpty) {
        uploadedImageUrls = await eventsService.uploadEventImages(
          _selectedImageBytes,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = 'Failed to upload images: $e';
      });
      return;
    }

    final success = await widget.onCreate(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrls: [..._imageUrls, ...uploadedImageUrls],
      websiteUrl: _websiteController.text.trim(),
      startAt: normalizedStartAt,
      endAt: normalizedEndAt,
      isDateOnly: _isDateOnly,
      timeZone: timeZone,
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
      address: _addressController.text.trim(),
      city: _currentCity,
      countryCode: _currentCountryCode,
      spotIds: _linkedSpots.map((spot) => spot.id!).toList(),
      spotListIds: _linkedLists.map((list) => list.id!).toList(),
    );
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _formError = eventsService.error ?? 'Create failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Event'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website URL (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/event',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final uri = Uri.tryParse(trimmed);
                    final valid =
                        uri != null &&
                        (uri.scheme == 'http' || uri.scheme == 'https') &&
                        uri.host.isNotEmpty;
                    if (!valid) return 'Enter a valid http(s) URL';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Event images',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _pickImagesFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Upload image(s)'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _newImageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Add image URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        onFieldSubmitted: (_) => _addImageUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSubmitting ? null : _addImageUrl,
                      icon: const Icon(Icons.add_link),
                      tooltip: 'Add image URL',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedImageBytes.isNotEmpty)
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImageBytes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedImageBytes[index],
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: _isSubmitting
                                    ? null
                                    : () => _removeSelectedImageAt(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _imageUrls
                        .asMap()
                        .entries
                        .map(
                          (entry) => Chip(
                            label: Text('URL ${entry.key + 1}'),
                            onDeleted: _isSubmitting
                                ? null
                                : () => _removeImageUrlAt(entry.key),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Event location',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: (_isSubmitting || _isGeocoding)
                          ? null
                          : () => _tryGeocodeCoordinatesIfNeeded(force: true),
                      icon: _isGeocoding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.pin_drop_outlined),
                      label: const Text('Geocode'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (auto-filled from coordinates)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text('Schedule', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTimeZone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    border: OutlineInputBorder(),
                  ),
                  items: _timeZoneOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            _timeZoneLabel(value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedTimeZone = value);
                        },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date only (no times)'),
                  subtitle: const Text(
                    'Display this event everywhere without times',
                  ),
                  value: _isDateOnly,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() => _isDateOnly = value);
                        },
                ),
                const SizedBox(height: 8),
                _DateField(
                  label: _isDateOnly ? 'Start date' : 'Start date & time',
                  value: _startAt,
                  isDateOnly: _isDateOnly,
                  timeZone: _effectiveTimeZone,
                  onPick: _pickStartAt,
                ),
                const SizedBox(height: 8),
                _DateField(
                  label: _isDateOnly
                      ? 'End date (optional)'
                      : 'End date & time (optional)',
                  value: _endAt,
                  isDateOnly: _isDateOnly,
                  timeZone: _effectiveTimeZone,
                  onPick: _pickEndAt,
                  onClear: _endAt == null
                      ? null
                      : () {
                          setState(() {
                            _endAt = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Linked spots',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _addLinkedSpot,
                      icon: const Icon(Icons.add),
                      label: const Text('Add spot'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_linkedSpots.isEmpty)
                  Text(
                    'No spots selected yet',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _linkedSpots
                        .map(
                          (spot) => Chip(
                            label: Text('${spot.name} (${spot.id})'),
                            onDeleted: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _linkedSpots.removeWhere(
                                        (s) => s.id == spot.id,
                                      );
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Linked spot lists',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _addLinkedList,
                      icon: const Icon(Icons.add),
                      label: const Text('Add list'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_linkedLists.isEmpty)
                  Text(
                    'No spot lists selected yet',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _linkedLists
                        .map(
                          (list) => Chip(
                            label: Text(
                              '${list.name} (${list.visibility.label})',
                            ),
                            onDeleted: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _linkedLists.removeWhere(
                                        (l) => l.id == list.id,
                                      );
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initial,
    String? timeZone,
  }) async {
    final displayInitial = EventScheduleUtils.toDisplayDateTime(
      initial,
      timeZone: timeZone,
    );
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: displayInitial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selectedDate == null || !context.mounted) return null;

    final initialTime = TimeOfDay.fromDateTime(displayInitial);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selectedTime == null) return null;

    return EventScheduleUtils.localDateTimeToUtc(
      DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
      timeZone: timeZone,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.isDateOnly,
    required this.timeZone,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final bool isDateOnly;
  final String? timeZone;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Not set'
        : EventScheduleUtils.formatSummaryLine(
            context,
            startAt: value!,
            isDateOnly: isDateOnly,
            timeZone: timeZone,
          );

    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $display',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Pick'),
        ),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }
}
