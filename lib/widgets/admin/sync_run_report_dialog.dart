import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/sync_run.dart';
import '../../services/sync_run_service.dart';

/// Opens the sync-run report dialog for [runId].
Future<void> showSyncRunReportDialog(
  BuildContext context, {
  required String runId,
  SyncRunService? syncRunService,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => SyncRunReportDialog(
      runId: runId,
      syncRunService: syncRunService,
    ),
  );
}

class SyncRunReportDialog extends StatefulWidget {
  const SyncRunReportDialog({
    super.key,
    required this.runId,
    this.syncRunService,
  });

  final String runId;
  final SyncRunService? syncRunService;

  @override
  State<SyncRunReportDialog> createState() => _SyncRunReportDialogState();
}

class _SyncRunReportDialogState extends State<SyncRunReportDialog> {
  late final SyncRunService _service;
  SyncRun? _run;
  String? _error;
  bool _loading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _service = widget.syncRunService ?? SyncRunService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _run = null;
    });
    try {
      final run = await _service.fetchById(widget.runId);
      if (!mounted) return;
      if (run == null) {
        setState(() {
          _error = 'Sync run not found';
          _loading = false;
        });
        return;
      }
      setState(() {
        _run = run;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyReport() async {
    final run = _run;
    if (run == null) return;
    await Clipboard.setData(ClipboardData(text: run.toReportText()));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied')),
    );
  }

  Color _statusColor(ColorScheme scheme, SyncRun run) {
    if (run.isFailed) return scheme.error;
    if (run.isSucceeded) return scheme.primary;
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final run = _run;

    return AlertDialog(
      title: Text(
        run == null
            ? 'Sync run'
            : '${run.sourceName} · ${run.syncType}',
      ),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? SelectableText(
                _error!,
                style: TextStyle(color: scheme.error),
              )
            : run == null
            ? const Text('No data')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.status,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _statusColor(scheme, run),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _metaLine(
                      'Invocations: ${run.invocationCount}'
                      '${run.trigger != null ? ' · ${run.trigger}' : ''}',
                    ),
                    if (run.startedAt != null)
                      _metaLine('Started: ${run.startedAt}'),
                    if (run.finishedAt != null)
                      _metaLine('Finished: ${run.finishedAt}'),
                    if (run.errorMessage != null &&
                        run.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Error',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        run.errorMessage!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    if (run.stats.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Stats',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      ...run.stats.entries.map(
                        (e) => SelectableText('  ${e.key}: ${e.value}'),
                      ),
                    ],
                    ..._listSection('Added', run.added),
                    ..._listSection('Updated', run.updated),
                    ..._listSection('Removed', run.removed),
                    if (run.issues.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Media issues (${run.issues.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      ...run.issues.map((issue) {
                        final parts = <String>[
                          if (issue['type'] != null) issue['type'].toString(),
                          if (issue['videoId'] != null)
                            issue['videoId'].toString(),
                          if (issue['spotName'] != null)
                            issue['spotName'].toString(),
                        ];
                        return SelectableText('  ${parts.join(' · ')}');
                      }),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: run == null ? null : _copyReport,
          icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
          label: Text(_copied ? 'Copied' : 'Copy report'),
        ),
      ],
    );
  }

  Widget _metaLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SelectableText(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _listSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Text(
        '$title (${items.length})',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      ...items.map((item) {
        final name = item['name']?.toString();
        final id = item['id']?.toString();
        return SelectableText('  ${name ?? id ?? item.toString()}');
      }),
    ];
  }
}
