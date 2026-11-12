import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class BrokenOutgoingLinksScreen extends StatelessWidget {
  const BrokenOutgoingLinksScreen({
    super.key,
    required this.findings,
    required this.totalHttpChecks,
    required this.uniqueUrlsChecked,
  });

  final List<Map<String, dynamic>> findings;
  final int totalHttpChecks;
  final int uniqueUrlsChecked;

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openEntity(BuildContext context, Map<String, dynamic> item) {
    final type = item['entityType'] as String? ?? '';
    final id = item['entityId'] as String? ?? '';
    if (id.isEmpty) return;
    switch (type) {
      case 'event':
        context.push('/event/$id');
        break;
      case 'spotList':
        context.push('/list/$id');
        break;
    }
  }

  String _entityTypeLabel(String? type) {
    switch (type) {
      case 'event':
        return 'Event';
      case 'spotList':
        return 'Spot list';
      default:
        return 'Entity';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...findings]
      ..sort((a, b) {
        final typeCmp = (a['entityType'] as String? ?? '')
            .compareTo(b['entityType'] as String? ?? '');
        if (typeCmp != 0) return typeCmp;
        final nameA = (a['entityName'] as String? ?? '').toLowerCase();
        final nameB = (b['entityName'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Broken outgoing links (${sorted.length})'),
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
                  Text('Problem links: ${sorted.length}'),
                  Text('HTTP checks performed: $totalHttpChecks'),
                  Text('Unique URLs in cache: $uniqueUrlsChecked'),
                  const SizedBox(height: 8),
                  Text(
                    'Current/upcoming events (website URL) and spot lists '
                    '(more info link). Checks use HEAD with GET fallback, '
                    'with pauses between requests.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No broken outgoing links found.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final item = sorted[index];
                      final entityName =
                          item['entityName'] as String? ?? 'Untitled';
                      final entityType = item['entityType'] as String?;
                      final field = item['field'] as String? ?? 'url';
                      final rawUrl = item['rawUrl'] as String? ?? '';
                      final reason = item['reason'] as String? ?? 'broken';
                      final statusCode = item['statusCode'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(entityName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_entityTypeLabel(entityType)} · $field',
                                style: const TextStyle(fontSize: 12),
                              ),
                              SelectableText(rawUrl),
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
                              if (value == 'entity') {
                                _openEntity(context, item);
                              } else if (value == 'url') {
                                _openUrl(
                                  item['normalizedUrl'] as String? ?? rawUrl,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'entity',
                                child: Text('Open item'),
                              ),
                              const PopupMenuItem(
                                value: 'url',
                                child: Text('Open URL'),
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
