import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_management_service.dart';
import '../../widgets/page_scaffold.dart';

class UserActivityMetricsScreen extends StatefulWidget {
  const UserActivityMetricsScreen({super.key});

  @override
  State<UserActivityMetricsScreen> createState() => _UserActivityMetricsScreenState();
}

class _UserActivityMetricsScreenState extends State<UserActivityMetricsScreen> {
  @override
  void initState() {
    super.initState();
    // Load any existing metrics data if needed
  }

  Future<void> _calculateMetrics() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calculate User Activity Metrics'),
        content: const Text(
          'This will calculate Daily Active Users (DAU), Weekly Active Users (WAU), '
          'and Monthly Active Users (MAU) based on user lastActiveAt timestamps. '
          'The metrics will be stored in Firestore and synced to Google Sheets. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Calculate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculating metrics...')),
    );

    try {
      final userManagementService = Provider.of<UserManagementService>(context, listen: false);
      final result = await userManagementService.calculateUserActivityMetrics();

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final metrics = result['metrics'] as Map<String, dynamic>?;
        final date = result['date'] as String?;
        final rowsSynced = result['rowsSynced'] as int?;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Success! Calculated metrics for $date. '
              'DAU: ${metrics?['dau'] ?? 0}, '
              'WAU: ${metrics?['wau'] ?? 0}, '
              'MAU: ${metrics?['mau'] ?? 0}. '
              'Synced $rowsSynced rows to Google Sheets.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculation completed but no result returned'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return PageScaffold(
        title: 'User Activity Metrics',
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64),
              SizedBox(height: 12),
              Text('Administrator access required'),
            ],
          ),
        ),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    final userManagementService = context.watch<UserManagementService>();
    final isCalculating = userManagementService.isCalculatingMetrics;
    final error = userManagementService.metricsError;
    final lastResult = userManagementService.lastMetricsResult;

    return PageScaffold(
      title: 'User Activity Metrics',
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/admin');
        }
      },
      actions: [
        if (isCalculating)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton.icon(
            onPressed: _calculateMetrics,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What this does',
                    style: TextStyle( fontSize: 18),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Calculates Daily Active Users (DAU): Users active in the last 24 hours',
                  ),
                  Text(
                    '• Calculates Weekly Active Users (WAU): Users active in the last 7 days',
                  ),
                  Text(
                    '• Calculates Monthly Active Users (MAU): Users active in the last 30 days',
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Stores metrics in Firestore (userActivityMetrics collection)',
                  ),
                  Text(
                    '• Syncs all historical metrics to Google Sheets for Looker Studio',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Note: This function runs automatically every night at 1 minute after midnight UTC. '
                    'You can trigger it manually here for testing.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (lastResult != null && lastResult['success'] == true) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Calculation Result',
                      style: TextStyle( fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    if (lastResult['date'] != null)
                      Text('Date: ${lastResult['date']}'),
                    const SizedBox(height: 8),
                    if (lastResult['metrics'] != null) ...[
                      const Text(
                        'Metrics:',
                        style: TextStyle(),
                      ),
                      const SizedBox(height: 4),
                      Text('  • DAU: ${lastResult['metrics']['dau'] ?? 0}'),
                      Text('  • WAU: ${lastResult['metrics']['wau'] ?? 0}'),
                      Text('  • MAU: ${lastResult['metrics']['mau'] ?? 0}'),
                      const SizedBox(height: 8),
                    ],
                    if (lastResult['rowsSynced'] != null)
                      Text('Rows synced to Google Sheets: ${lastResult['rowsSynced']}'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
