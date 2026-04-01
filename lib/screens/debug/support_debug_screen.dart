import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:parkour_spot/utils/support_debug_report.dart';

/// Hidden support page: open at `/debug` (not linked in the app).
class SupportDebugScreen extends StatelessWidget {
  const SupportDebugScreen({super.key});

  Future<void> _copyReport(BuildContext context) async {
    final text = buildSupportDebugReportText(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = buildSupportDebugReportSections(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support debug info'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/explore');
            }
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.icon(
              onPressed: () => _copyReport(context),
              icon: const Icon(Icons.copy, size: 20),
              label: const Text('Copy report'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'For support: copy and send this report. Nothing here is linked from the app.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        for (final row in section.rows) ...[
                          Text(
                            row.key,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            row.value,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(height: 12),
                        ],
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
