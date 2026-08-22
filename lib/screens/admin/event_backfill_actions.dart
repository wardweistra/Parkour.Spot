import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_events_service.dart';
import '../../utils/search_index_backfill_message.dart';

/// Admin-only event index backfills, shown from Event data.
class EventBackfillActions {
  EventBackfillActions._();

  static Future<void> backfillEventSearchTerms(BuildContext context) async {
    var purgeTerms = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Backfill event name search'),
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
    if (confirm != true || !context.mounted) return;

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
      if (!context.mounted) return;

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
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Event search terms backfill failed: $e'),
        ),
      );
    }
  }

  static Future<void> showBackfillEventMapPinsDialog(
    BuildContext context,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backfill event map pins'),
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
                _runBackfillEventMapPins(context);
              },
              child: const Text('All Events'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showBackfillEventSelectionDialog(context);
              },
              child: const Text('Select Event'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showBackfillEventSelectionDialog(
    BuildContext context,
  ) async {
    final eventsService = context.read<AdminEventsService>();
    if (eventsService.events.isEmpty) {
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
                Text('Loading events...'),
              ],
            ),
          );
        },
      );
      await eventsService.fetchEvents();
      progressNavigator.pop();
      if (!context.mounted) return;
    }

    final events = [...eventsService.events]
      ..sort((a, b) => a.title.compareTo(b.title));

    if (events.isEmpty) {
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
                    _runBackfillEventMapPins(context, eventId: id);
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

  static Future<void> _runBackfillEventMapPins(
    BuildContext context, {
    String? eventId,
  }) async {
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
      if (!context.mounted) return;

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
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Event map pins backfill failed: $e'),
        ),
      );
    }
  }
}
