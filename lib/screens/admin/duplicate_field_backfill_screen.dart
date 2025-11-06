import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/spot_service.dart';

class DuplicateFieldBackfillScreen extends StatefulWidget {
  const DuplicateFieldBackfillScreen({super.key});

  @override
  State<DuplicateFieldBackfillScreen> createState() => _DuplicateFieldBackfillScreenState();
}

class _DuplicateFieldBackfillScreenState extends State<DuplicateFieldBackfillScreen> {
  bool _isRunning = false;
  Map<String, int>? _lastStats;
  String? _error;

  Future<void> _runBackfill() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _error = null;
    });

    final spotService = context.read<SpotService>();

    spotService.clearError();

    try {
      final stats = await spotService.backfillMissingDuplicateOf();
      if (!mounted) return;

      setState(() {
        _lastStats = stats;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backfill complete. Updated ${stats['updated']} spot(s).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backfill failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((service) => service.isAdmin);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate Field Backfill')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    final spotService = context.watch<SpotService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backfill Duplicate Field'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('What this does', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Finds spots where the duplicateOf field is missing'),
                  Text('• Sets duplicateOf to null so all records have the field'),
                  Text('• Does NOT change spots already marked as duplicates'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (_lastStats != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildStatRow('Matched spots', _lastStats!['matched']),
                    const SizedBox(height: 8),
                    _buildStatRow('Updated spots', _lastStats!['updated']),
                    const SizedBox(height: 8),
                    _buildStatRow('Already had field', _lastStats!['skipped']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spot service status: ${spotService.isLoading ? 'Busy' : 'Idle'}'),
                  if (spotService.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      spotService.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runBackfill,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isRunning ? 'Running...' : 'Run Backfill'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int? value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text((value ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
