import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sync_source_service.dart';
import '../services/spot_service.dart';

class SourceDetailsDialog extends StatelessWidget {
  final SyncSource source;

  const SourceDetailsDialog({
    super.key,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SpotService>(
      builder: (context, spotService, child) {
        return FutureBuilder<int>(
          future: spotService.getSpotCountForSource(source.id),
          builder: (context, snapshot) {
            final spotCount = snapshot.data ?? 0;
            
            return AlertDialog(
              title: Text(source.name),
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
                      Text(source.description!),
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
                    if (source.publicUrl != null && source.publicUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchUrl(source.publicUrl!),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Go to Source'),
                        ),
                      ),
                    ],
                    if (source.createdAt != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Created',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(_formatDateTime(source.createdAt!)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
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
