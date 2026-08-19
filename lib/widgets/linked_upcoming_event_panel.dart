import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../utils/event_schedule_utils.dart';
import '../utils/upcoming_linked_events_utils.dart';

/// Compact callout for events linked to a spot or spot list.
///
/// Shows the next upcoming event (teal) when any exist; otherwise the most
/// recent past event (muted). A single action opens every linked event.
class LinkedUpcomingEventPanel extends StatelessWidget {
  const LinkedUpcomingEventPanel({
    super.key,
    required this.eventsFuture,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.compact = false,
    this.now,
  });

  final Future<LinkedSpotEvents>? eventsFuture;
  final EdgeInsetsGeometry margin;
  final bool compact;

  /// Clock used to label happening vs past events. Defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkedSpotEvents>(
      future:
          eventsFuture ??
          Future<LinkedSpotEvents>.value(const LinkedSpotEvents()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final events = snapshot.data ?? const LinkedSpotEvents();
        final featured = events.featured;
        if (featured == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = Theme.of(context).colorScheme;
        final clock = now;
        final featuredTiming = featured.timing(now: clock);
        final highlighted = events.featuresUpcoming;
        final more = linkedEventsMoreAction(events);
        final moreLabel = more == null
            ? null
            : more.kind == LinkedEventsMoreKind.pastOnly
            ? l10n.detailPastEventsAndMore(more.count)
            : l10n.detailUpcomingEventsAndMore(more.count);

        final heading = switch (featuredTiming) {
          LinkedEventTiming.happening => l10n.detailLinkedEventHappeningLabel,
          LinkedEventTiming.past => l10n.detailPastEventLabel(
            events.past.length,
          ),
          LinkedEventTiming.upcoming => l10n.detailUpcomingEventLabel(
            events.upcoming.length,
          ),
        };

        return Padding(
          padding: margin,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: highlighted
                  ? colors.primaryContainer.withValues(alpha: 0.35)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              border: highlighted
                  ? Border.all(color: colors.primary.withValues(alpha: 0.25))
                  : SpotDetailUi.outlineBorder(colors),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => context.push('/event/${featured.id}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            highlighted
                                ? Icons.event_available_outlined
                                : Icons.history,
                            color: highlighted
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            size: compact ? 20 : 24,
                          ),
                          SizedBox(width: compact ? 8 : 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  heading,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: highlighted
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                        fontSize: compact ? 12 : null,
                                      ),
                                ),
                                SizedBox(height: compact ? 2 : 4),
                                Text(
                                  featured.title,
                                  style: compact
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
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
                                  EventScheduleUtils.formatSummaryLine(
                                    context,
                                    startAt: featured.startAt,
                                    endAt: featured.endAt,
                                    isDateOnly: featured.isDateOnly,
                                    timeZone: featured.timeZone,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontSize: compact ? 11 : null),
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
                if (moreLabel != null) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => _showEventsSheet(
                        context,
                        events: events,
                        title: l10n.detailUpcomingEventsSheetTitle,
                        clock: clock,
                      ),
                      borderRadius: BorderRadius.circular(
                        SpotDetailUi.surfaceRadius,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: highlighted ? 0.55 : 0.7,
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
                                  color: highlighted
                                      ? colors.primary
                                      : colors.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  moreLabel,
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

  void _showEventsSheet(
    BuildContext context, {
    required LinkedSpotEvents events,
    required String title,
    DateTime? clock,
  }) {
    final sheetEvents = linkedEventsSheetOrder(events);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        final colors = Theme.of(sheetContext).colorScheme;
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
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: sheetEvents.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = sheetEvents[index];
                      final timing = event.timing(now: clock);
                      final whenText = EventScheduleUtils.formatSummaryLine(
                        context,
                        startAt: event.startAt,
                        endAt: event.endAt,
                        isDateOnly: event.isDateOnly,
                        timeZone: event.timeZone,
                      );
                      final statusLabel = switch (timing) {
                        LinkedEventTiming.happening =>
                          l10n.detailLinkedEventHappeningLabel,
                        LinkedEventTiming.past =>
                          l10n.detailLinkedEventPastLabel,
                        LinkedEventTiming.upcoming => null,
                      };
                      final statusColor = switch (timing) {
                        LinkedEventTiming.happening => colors.primary,
                        LinkedEventTiming.past => colors.onSurfaceVariant,
                        LinkedEventTiming.upcoming => colors.primary,
                      };
                      final leadingIcon = switch (timing) {
                        LinkedEventTiming.happening =>
                          Icons.event_available_outlined,
                        LinkedEventTiming.past => Icons.history,
                        LinkedEventTiming.upcoming => Icons.event_outlined,
                      };
                      return ListTile(
                        leading: Icon(leadingIcon, color: statusColor),
                        title: Text(event.title),
                        subtitle: statusLabel == null
                            ? Text(whenText)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(whenText),
                                ],
                              ),
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
