import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../services/event_sync_source_service.dart';
import '../utils/event_schedule_utils.dart';

class EventsOverviewFilterBar extends StatelessWidget {
  const EventsOverviewFilterBar({
    super.key,
    required this.service,
    required this.onEventSourceChanged,
    required this.onUpcomingOnlyChanged,
    required this.onExcludeDuplicatesChanged,
    required this.onExcludeHiddenChanged,
    required this.onWithoutLocationOnlyChanged,
    this.onNeedsModeratorReviewOnlyChanged,
    this.showNeedsModeratorReviewFilter = false,
  });

  final AdminEventsService service;
  final ValueChanged<String?>? onEventSourceChanged;
  final ValueChanged<bool>? onUpcomingOnlyChanged;
  final ValueChanged<bool>? onExcludeDuplicatesChanged;
  final ValueChanged<bool>? onExcludeHiddenChanged;
  final ValueChanged<bool>? onWithoutLocationOnlyChanged;
  final ValueChanged<bool>? onNeedsModeratorReviewOnlyChanged;
  final bool showNeedsModeratorReviewFilter;

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
                  label: const Text('Exclude hidden'),
                  selected: service.excludeHidden,
                  onSelected: onExcludeHiddenChanged == null
                      ? null
                      : (selected) => onExcludeHiddenChanged!(selected),
                ),
                FilterChip(
                  label: const Text('Without location only'),
                  selected: service.withoutLocationOnly,
                  onSelected: onWithoutLocationOnlyChanged == null
                      ? null
                      : (selected) => onWithoutLocationOnlyChanged!(selected),
                ),
                if (showNeedsModeratorReviewFilter)
                  FilterChip(
                    label: const Text('Needs review only'),
                    selected: service.needsModeratorReviewOnly,
                    onSelected: onNeedsModeratorReviewOnlyChanged == null
                        ? null
                        : (selected) =>
                              onNeedsModeratorReviewOnlyChanged!(selected),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EventsOverviewBody extends StatelessWidget {
  const EventsOverviewBody({
    super.key,
    required this.service,
    this.showModeratorReviewActions = false,
    this.onMarkReviewed,
  });

  final AdminEventsService service;
  final bool showModeratorReviewActions;
  final Future<void> Function(ParkourEvent event)? onMarkReviewed;

  @override
  Widget build(BuildContext context) {
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
            return EventsOverviewLoadMoreFooter(service: service);
          }
          return EventsOverviewCard(
            event: service.events[index],
            showModeratorReviewActions: showModeratorReviewActions,
            onMarkReviewed: onMarkReviewed,
          );
        },
      ),
    );
  }
}

class EventsOverviewCard extends StatelessWidget {
  const EventsOverviewCard({
    super.key,
    required this.event,
    this.showModeratorReviewActions = false,
    this.onMarkReviewed,
  });

  final ParkourEvent event;
  final bool showModeratorReviewActions;
  final Future<void> Function(ParkourEvent event)? onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final sourceName = event.eventSourceName?.trim();
    final hasSource = sourceName != null && sourceName.isNotEmpty;
    final duplicateOfId = event.duplicateOf?.trim();
    final hasDuplicateLink = duplicateOfId != null && duplicateOfId.isNotEmpty;
    final description = event.description?.trim() ?? '';
    final openEventPage = event.id == null
        ? null
        : () => context.push('/event/${event.id}');
    final statusChips = _statusChips(colors);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: openEventPage,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (event.id != null) ...[
                    IconButton(
                      onPressed: openEventPage,
                      tooltip: 'Open event page',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _EventsOverviewWhen(
                startAt: event.startAt,
                endAt: event.endAt,
                isDateOnly: event.isDateOnly,
                timeZone: event.timeZone,
                todayLabel: l10n.spotDetailDateToday,
              ),
              if (statusChips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: statusChips),
              ],
              if (hasDuplicateLink) ...[
                const SizedBox(height: 10),
                EventDuplicateChip(
                  originalEventId: duplicateOfId,
                  duplicateOfLabel: l10n.spotDetailDuplicateOf,
                  originalTitleFallback: l10n.eventDetailOriginalEventFallback,
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
              if (_metaItems(sourceName).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: _metaItems(sourceName),
                ),
              ],
              if (hasSource &&
                  (event.externalSyncLastSeenAt != null ||
                      event.externalSyncLastChangedAt != null)) ...[
                const SizedBox(height: 6),
                Text(
                  _syncMetaLine(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (event.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                            color: colors.surfaceContainerHighest,
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              if (event.id != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showModeratorReviewActions &&
                        event.needsModeratorReview &&
                        onMarkReviewed != null)
                      FilledButton.icon(
                        onPressed: () => onMarkReviewed!(event),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark reviewed'),
                      ),
                    if (showModeratorReviewActions &&
                        event.needsModeratorReview &&
                        onMarkReviewed != null)
                      const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: openEventPage,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open event page'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _statusChips(ColorScheme colors) {
    return [
      if (event.needsModeratorReview)
        _EventStatusChip(
          label: 'Needs review',
          icon: Icons.flag_outlined,
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      if (!event.hasLocation)
        _EventStatusChip(
          label: 'No location',
          icon: Icons.location_off_outlined,
          background: colors.surfaceContainerHighest,
          foreground: colors.onSurface,
          outlined: true,
          outlineColor: colors.outline.withValues(alpha: 0.35),
        ),
      if (event.hidden)
        _EventStatusChip(
          label: 'Hidden',
          icon: Icons.visibility_off_outlined,
          background: colors.errorContainer,
          foreground: colors.onErrorContainer,
        ),
      if (event.isDuplicate)
        _EventStatusChip(
          label: 'Duplicate',
          icon: Icons.copy_all_outlined,
          background: colors.secondaryContainer,
          foreground: colors.onSecondaryContainer,
        ),
    ];
  }

  List<Widget> _metaItems(String? sourceName) {
    final city = event.city?.trim();
    final address = event.address?.trim();
    final locationLabel = (city != null && city.isNotEmpty)
        ? city
        : (address != null && address.isNotEmpty)
        ? address
        : (event.latitude != null && event.longitude != null)
        ? '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}'
        : null;

    return [
      if (locationLabel != null)
        _EventMetaItem(icon: Icons.place_outlined, label: locationLabel),
      if (event.spotIds.isNotEmpty)
        _EventMetaItem(
          icon: Icons.place_outlined,
          label: event.spotIds.length == 1
              ? '1 linked spot'
              : '${event.spotIds.length} linked spots',
        ),
      if (event.spotListIds.isNotEmpty)
        _EventMetaItem(
          icon: Icons.list_outlined,
          label: event.spotListIds.length == 1
              ? '1 linked list'
              : '${event.spotListIds.length} linked lists',
        ),
      if (sourceName != null && sourceName.isNotEmpty)
        _EventMetaItem(icon: Icons.sync, label: sourceName),
    ];
  }

  String _syncMetaLine(BuildContext context) {
    final parts = <String>[];
    if (event.externalSyncLastSeenAt != null) {
      parts.add('Seen ${_formatUtc(context, event.externalSyncLastSeenAt!)}');
    }
    if (event.externalSyncLastChangedAt != null) {
      parts.add(
        'changed ${_formatUtc(context, event.externalSyncLastChangedAt!)}',
      );
    }
    return parts.join(' · ');
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

class _EventsOverviewWhen extends StatelessWidget {
  const _EventsOverviewWhen({
    required this.startAt,
    this.endAt,
    required this.isDateOnly,
    this.timeZone,
    required this.todayLabel,
  });

  final DateTime startAt;
  final DateTime? endAt;
  final bool isDateOnly;
  final String? timeZone;
  final String todayLabel;

  bool _isToday(DateTime instant) {
    final local = EventScheduleUtils.toDisplayDateTime(
      instant,
      timeZone: timeZone,
    );
    final now = EventScheduleUtils.toDisplayDateTime(
      DateTime.now().toUtc(),
      timeZone: timeZone,
    );
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  String _formatDate(MaterialLocalizations localizations, DateTime display) {
    final base = localizations.formatMediumDate(display);
    final currentYear = EventScheduleUtils.toDisplayDateTime(
      DateTime.now().toUtc(),
      timeZone: timeZone,
    ).year;
    return display.year == currentYear ? base : '$base ${display.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final start = EventScheduleUtils.toDisplayDateTime(
      startAt,
      timeZone: timeZone,
    );
    final end = endAt == null
        ? null
        : EventScheduleUtils.toDisplayDateTime(endAt!, timeZone: timeZone);
    final sameDay =
        endAt != null &&
        EventScheduleUtils.isSameCalendarDay(
          startAt,
          endAt!,
          timeZone: timeZone,
        );
    final showToday = _isToday(startAt) || (endAt != null && _isToday(endAt!));
    final zoneSuffix = EventScheduleUtils.normalizeTimeZone(timeZone) == null
        ? ''
        : ' ${start.timeZoneName}';

    final startDate = _formatDate(localizations, start);
    final endDate = end == null ? null : _formatDate(localizations, end);
    final dateLine = (end == null || sameDay)
        ? startDate
        : '$startDate – $endDate';

    String? timeLine;
    if (!isDateOnly) {
      final startTime = localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(start),
      );
      if (end == null) {
        timeLine = '$startTime$zoneSuffix';
      } else {
        final endTime = localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(end),
        );
        timeLine = '$startTime – $endTime$zoneSuffix';
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: showToday ? 2 : 1),
          child: Icon(
            Icons.event_available_outlined,
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showToday) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    todayLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                dateLine,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (timeLine != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.outlined = false,
    this.outlineColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool outlined;
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: background,
      side: outlined
          ? BorderSide(color: outlineColor ?? foreground, width: 1)
          : BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _EventMetaItem extends StatelessWidget {
  const _EventMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventDuplicateChip extends StatefulWidget {
  const EventDuplicateChip({
    super.key,
    required this.originalEventId,
    required this.duplicateOfLabel,
    required this.originalTitleFallback,
  });

  final String originalEventId;
  final String duplicateOfLabel;
  final String originalTitleFallback;

  @override
  State<EventDuplicateChip> createState() => _EventDuplicateChipState();
}

class _EventDuplicateChipState extends State<EventDuplicateChip> {
  String? _originalTitle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOriginalTitle();
  }

  @override
  void didUpdateWidget(covariant EventDuplicateChip oldWidget) {
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

class EventsOverviewLoadMoreFooter extends StatelessWidget {
  const EventsOverviewLoadMoreFooter({super.key, required this.service});

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
