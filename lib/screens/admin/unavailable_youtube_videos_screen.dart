import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class UnavailableYoutubeVideosScreen extends StatelessWidget {
  const UnavailableYoutubeVideosScreen({
    super.key,
    required this.findings,
    required this.totalOembedChecks,
    required this.uniqueVideosInCache,
  });

  final List<Map<String, dynamic>> findings;
  final int totalOembedChecks;
  final int uniqueVideosInCache;

  Future<void> _openVideo(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSpot(BuildContext context, String spotId) {
    context.push('/spot/$spotId');
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...findings]
      ..sort((a, b) {
        final nameA = (a['spotName'] as String? ?? '').toLowerCase();
        final nameB = (b['spotName'] as String? ?? '').toLowerCase();
        final byName = nameA.compareTo(nameB);
        if (byName != 0) return byName;
        return (a['videoId'] as String? ?? '')
            .compareTo(b['videoId'] as String? ?? '');
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Unavailable YouTube videos (${sorted.length})'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Unavailable links found: ${sorted.length}'),
                  Text('oEmbed checks performed: $totalOembedChecks'),
                  Text('Unique videos resolved: $uniqueVideosInCache'),
                  const SizedBox(height: 8),
                  Text(
                    'Checks use YouTube’s public oEmbed API with pauses between '
                    'requests so we do not hammer their servers.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No unavailable YouTube videos found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final item = sorted[index];
                      final spotName = item['spotName'] as String? ?? 'Spot';
                      final spotId = item['spotId'] as String? ?? '';
                      final videoId = item['videoId'] as String? ?? '';
                      final reason = item['reason'] as String? ?? 'unavailable';
                      final statusCode = item['statusCode'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(spotName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText('Video: $videoId'),
                              SelectableText('Spot ID: $spotId'),
                              Text(
                                'Reason: $reason'
                                '${statusCode != null ? ' (HTTP $statusCode)' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'spot' && spotId.isNotEmpty) {
                                _openSpot(context, spotId);
                              } else if (value == 'video' && videoId.isNotEmpty) {
                                _openVideo(videoId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'spot',
                                child: Text('Open spot'),
                              ),
                              const PopupMenuItem(
                                value: 'video',
                                child: Text('Open on YouTube'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
