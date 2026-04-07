import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../l10n/app_localizations.dart';
import '../services/sync_source_service.dart';
import 'instagram_button.dart';

/// Displays full details for a sync source.
/// Pass [source] when already loaded (e.g. from spot detail), or [sourceId]
/// for lazy loading (e.g. from filter tab - fetches on open).
class SourceDetailsDialog extends StatefulWidget {
  final SyncSource? source;
  final String? sourceId;

  const SourceDetailsDialog({
    super.key,
    this.source,
    this.sourceId,
  }) : assert(source != null || sourceId != null,
       'Either source or sourceId must be provided');

  @override
  State<SourceDetailsDialog> createState() => _SourceDetailsDialogState();
}

class _SourceDetailsDialogState extends State<SourceDetailsDialog> {
  SyncSource? _source;
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
    final service = Provider.of<SyncSourceService>(context, listen: false);
    final source = await service.fetchSyncSourceById(widget.sourceId!);
    if (!mounted) return;
    setState(() {
      _source = source;
      _isLoading = false;
      _error = source == null ? _l10n.exploreSourcesLoadError : null;
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
                _l10n.sourceDetailsLoadingSource,
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

  Widget _buildContent(SyncSource source) {
    // Callable/JSON numbers are often double at runtime; normalize for display.
    final spotCount =
        (source.lastSyncStats?['total'] as num?)?.toInt() ?? 0;

    return AlertDialog(
      title: SelectableText(source.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (source.description != null && source.description!.isNotEmpty) ...[
              Text(
                _l10n.spotDetailFieldDescription,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(source.description!),
              const SizedBox(height: 16),
            ],
            Text(
              _l10n.sourceDetailsTotalSpots,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _l10n.exploreSpotCountShort(spotCount),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (source.allFolders != null && source.allFolders!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _l10n.sourceDetailsFolders,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: source.allFolders!.map((folder) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              folder,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
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
            if (source.instagramHandle != null && source.instagramHandle!.isNotEmpty) ...[
              const SizedBox(height: 16),
              PointerInterceptor(
                child: InstagramButton(handle: source.instagramHandle!),
              ),
            ],
            if (source.createdAt != null) ...[
              const SizedBox(height: 16),
              Text(
                _l10n.sourceDetailsAdded,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(source.createdAt!)),
            ],
            if (source.lastSyncAt != null) ...[
              const SizedBox(height: 16),
              Text(
                _l10n.sourceDetailsLastImported,
                style: TextStyle(fontWeight: FontWeight.bold),
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
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
