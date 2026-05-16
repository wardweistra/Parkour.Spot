import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/event_sync_source_service.dart';

/// Displays public details for an imported event calendar source.
/// Pass [source] when already loaded, or [sourceId] for lazy loading.
class EventSourceDetailsDialog extends StatefulWidget {
  final EventSyncSource? source;
  final String? sourceId;

  const EventSourceDetailsDialog({
    super.key,
    this.source,
    this.sourceId,
  }) : assert(
         source != null || sourceId != null,
         'Either source or sourceId must be provided',
       );

  @override
  State<EventSourceDetailsDialog> createState() =>
      _EventSourceDetailsDialogState();
}

class _EventSourceDetailsDialogState extends State<EventSourceDetailsDialog> {
  EventSyncSource? _source;
  bool _isLoading = true;
  String? _error;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) {
      _source = widget.source;
      _isLoading = false;
    } else {
      _loadSource();
    }
  }

  Future<void> _loadSource() async {
    final service = context.read<EventSyncSourceService>();
    final source = await service.fetchEventSyncSourceById(widget.sourceId!);
    if (!mounted) return;
    setState(() {
      _source = source;
      _isLoading = false;
      _error = source == null ? _l10n.sourceDetailsNotFound : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AlertDialog(
        content: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(
                _l10n.eventSourceDetailsLoadingSource,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _source == null) {
      return AlertDialog(
        title: Text(_l10n.sourceDetailsErrorTitle),
        content: Text(_error ?? _l10n.sourceDetailsNotFound),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_l10n.spotDetailClose),
          ),
        ],
      );
    }

    return _buildContent(_source!);
  }

  Widget _buildContent(EventSyncSource source) {
    final stats = source.lastSyncStats;
    final eventCount = (stats?['totalUnique'] as num?)?.toInt() ??
        (stats?['created'] as num?)?.toInt() ??
        0;

    return AlertDialog(
      title: SelectableText(source.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (source.description != null &&
                source.description!.isNotEmpty) ...[
              Text(
                _l10n.spotDetailFieldDescription,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(source.description!),
              const SizedBox(height: 16),
            ],
            Text(
              _l10n.eventSourceDetailsTotalEvents,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _l10n.exploreEventCountShort(eventCount),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (source.publicUrl != null && source.publicUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              PointerInterceptor(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl(source.publicUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(_l10n.sourceDetailsGoToSource),
                  ),
                ),
              ),
            ],
            if (source.createdAt != null) ...[
              const SizedBox(height: 16),
              Text(
                _l10n.sourceDetailsAdded,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(source.createdAt!)),
            ],
            if (source.lastSyncAt != null) ...[
              const SizedBox(height: 16),
              Text(
                _l10n.sourceDetailsLastImported,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(source.lastSyncAt!)),
            ],
          ],
        ),
      ),
      actions: [
        PointerInterceptor(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_l10n.spotDetailClose),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return _l10n.sourceDetailsRelativeDaysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return _l10n.sourceDetailsRelativeHoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return _l10n.sourceDetailsRelativeMinutesAgo(difference.inMinutes);
    } else {
      return _l10n.sourceDetailsRelativeJustNow;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
