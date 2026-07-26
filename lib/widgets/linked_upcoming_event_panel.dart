import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../utils/event_schedule_utils.dart';
import '../utils/upcoming_linked_events_utils.dart';

/// Compact callout for upcoming events linked to a spot or spot list.
///
/// Shows the earliest event inline; tapping it opens that event. When more
/// than one exists, a secondary "N more events" chip opens a bottom sheet with
/// the full chronological list.
class LinkedUpcomingEventPanel extends StatelessWidget {
  const LinkedUpcomingEventPanel({
    super.key,
    required this.eventsFuture,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.compact = false,
  });

  final Future<List<UpcomingLinkedEvent>>? eventsFuture;
  final EdgeInsetsGeometry margin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UpcomingLinkedEvent>>(
      future: eventsFuture ?? Future<List<UpcomingLinkedEvent>>.value(const []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final events = snapshot.data ?? const <UpcomingLinkedEvent>[];
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = Theme.of(context).colorScheme;
        final event = events.first;
        final whenText = EventScheduleUtils.formatSummaryLine(
          context,
          startAt: event.startAt,
          endAt: event.endAt,
          isDateOnly: event.isDateOnly,
          timeZone: event.timeZone,
        );
        final moreCount = events.length - 1;
        final hasMore = moreCount > 0;

        return Padding(
          padding: margin,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => context.push('/event/${event.id}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            color: colors.primary,
                            size: compact ? 20 : 24,
                          ),
                          SizedBox(width: compact ? 8 : 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.detailUpcomingEventLabel(events.length),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: compact ? 12 : null,
                                      ),
                                ),
                                SizedBox(height: compact ? 2 : 4),
                                Text(
                                  event.title,
                                  style: compact
                                      ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            )
                                      : Theme.of(context).textTheme.titleSmall,
                                  maxLines: compact ? 2 : null,
                                  overflow: compact
                                      ? TextOverflow.ellipsis
                                      : null,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  whenText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: compact ? 11 : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: colors.onSurfaceVariant,
                            size: compact ? 20 : 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasMore) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => _showUpcomingEventsSheet(context, events),
                      borderRadius: BorderRadius.circular(
                        SpotDetailUi.surfaceRadius,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(
                              SpotDetailUi.surfaceRadius,
                            ),
                            border: SpotDetailUi.outlineBorder(colors),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.list_alt_outlined,
                                  size: 20,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.detailUpcomingEventsAndMore(moreCount),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: colors.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpcomingEventsSheet(
    BuildContext context,
    List<UpcomingLinkedEvent> events,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    l10n.detailUpcomingEventsSheetTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final whenText = EventScheduleUtils.formatSummaryLine(
                        context,
                        startAt: event.startAt,
                        endAt: event.endAt,
                        isDateOnly: event.isDateOnly,
                        timeZone: event.timeZone,
                      );
                      return ListTile(
                        leading: Icon(
                          Icons.event_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(event.title),
                        subtitle: Text(whenText),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/event/${event.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
