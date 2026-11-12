import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sync_source_service.dart';
import 'broken_outgoing_links_screen.dart';

/// Admin actions for scanning outgoing links on events and spot lists.
class OutgoingLinksAdminActions {
  OutgoingLinksAdminActions._();

  static Future<void> findBrokenOutgoingLinks(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Find broken outgoing links'),
        content: const Text(
          'Checks website URLs on current or upcoming events and '
          'more info links on spot lists. The scan runs in small batches '
          'with pauses between HTTP requests so remote sites are not hammered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Start scan'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final syncService = context.read<SyncSourceService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    late NavigatorState progressNavigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        progressNavigator = Navigator.of(c);
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Checking outgoing links (events, then spot lists)...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final result = await syncService.findBrokenOutgoingLinks();
      progressNavigator.pop();
      if (!context.mounted) return;

      if (result == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              syncService.error ?? 'Outgoing link scan failed',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final findingsRaw = result['findings'];
      final findings = findingsRaw is List
          ? findingsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final rateLimited = result['rateLimited'] == true;

      if (findings.isEmpty && result['success'] == true && !rateLimited) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('All checked outgoing links responded successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      if (findings.isEmpty && rateLimited) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'A remote host rate-limited the scan. Try again later.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BrokenOutgoingLinksScreen(
            findings: findings,
            totalHttpChecks: (result['totalHttpChecks'] as num?)?.toInt() ?? 0,
            uniqueUrlsChecked:
                (result['uniqueUrlsChecked'] as num?)?.toInt() ?? 0,
          ),
        ),
      );

      if (rateLimited && context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Partial results: rate limited. Wait and run again to continue.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      progressNavigator.pop();
      if (!context.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Outgoing link scan failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
