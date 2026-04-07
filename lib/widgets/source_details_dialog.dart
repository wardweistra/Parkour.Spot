import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
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
      _error = source == null ? 'Failed to load source' : null;
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
                'Loading source...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _source == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(_error ?? 'Source not found'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(source.description!),
              const SizedBox(height: 16),
            ],
            const Text(
              'Total Spots',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$spotCount spot${spotCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (source.allFolders != null && source.allFolders!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Folders',
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
                    label: const Text('Go to Source'),
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
              const Text(
                'Added',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(source.createdAt!)),
            ],
            if (source.lastSyncAt != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Last Imported',
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
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
