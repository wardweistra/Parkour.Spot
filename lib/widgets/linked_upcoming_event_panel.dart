import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../utils/event_schedule_utils.dart';

/// Compact callout for an upcoming event linked to a spot or spot list.
class LinkedUpcomingEventPanel extends StatelessWidget {
  const LinkedUpcomingEventPanel({
    super.key,
    required this.eventFuture,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.compact = false,
  });

  final Future<ParkourEvent?>? eventFuture;
  final EdgeInsetsGeometry margin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParkourEvent?>(
      future: eventFuture ?? Future<ParkourEvent?>.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final event = snapshot.data;
        if (event == null || event.id == null) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final colors = Theme.of(context).colorScheme;
        final whenText = EventScheduleUtils.formatSummaryLine(
          context,
          startAt: event.startAt,
          endAt: event.endAt,
          isDateOnly: event.isDateOnly,
          timeZone: event.timeZone,
        );

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
                        l10n.detailUpcomingEventLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : null,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        event.title,
                        style: compact
                            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              )
                            : Theme.of(context).textTheme.titleSmall,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                      ),
                      SizedBox(height: compact ? 2 : 2),
                      Text(
                        whenText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: compact ? 11 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/event/${event.id}'),
                  icon: Icon(Icons.open_in_new, size: compact ? 14 : 16),
                  label: Text(l10n.detailUpcomingEventOpen),
                  style: compact
                      ? TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
