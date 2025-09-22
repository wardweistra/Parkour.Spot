import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';

class LatLngMigrationScreen extends StatefulWidget {
  const LatLngMigrationScreen({super.key});

  @override
  State<LatLngMigrationScreen> createState() => _LatLngMigrationScreenState();
}

class _LatLngMigrationScreenState extends State<LatLngMigrationScreen> {
  Map<String, dynamic>? _lastResult;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Latitude/Longitude Migration')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    final geocodingService = context.watch<GeocodingService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latitude/Longitude Migration'),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _startMigration,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running...' : 'Run'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('What this does', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('• Finds all spots that have a location GeoPoint but missing latitude/longitude fields'),
                    Text('• Extracts latitude and longitude values from the location field'),
                    Text('• Adds these as separate latitude and longitude fields to each spot'),
                    SizedBox(height: 8),
                    Text('Note: This enables more efficient Firestore queries and improves performance.', 
                         style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (geocodingService.error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          geocodingService.error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (geocodingService.isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Migration in progress...'),
                    ],
                  ),
                ),
              ),
            if (_lastResult != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Migration Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_lastResult!['message'] != null) ...[
                        Text(
                          _lastResult!['message'],
                          style: TextStyle(
                            color: _lastResult!['success'] == true ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_lastResult!['stats'] != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              label: 'Total Spots',
                              value: _lastResult!['stats']['total']?.toString() ?? '0',
                              color: Colors.blue,
                            ),
                            _StatChip(
                              label: 'Processed',
                              value: _lastResult!['stats']['processed']?.toString() ?? '0',
                              color: Colors.orange,
                            ),
                            _StatChip(
                              label: 'Updated',
                              value: _lastResult!['stats']['updated']?.toString() ?? '0',
                              color: Colors.green,
                            ),
                            _StatChip(
                              label: 'Skipped',
                              value: _lastResult!['stats']['skipped']?.toString() ?? '0',
                              color: Colors.grey,
                            ),
                            _StatChip(
                              label: 'Failed',
                              value: _lastResult!['stats']['failed']?.toString() ?? '0',
                              color: Colors.red,
                            ),
                          ],
                        ),
                        if (_lastResult!['stats']['successRate'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Success Rate: ${_lastResult!['stats']['successRate']}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _testSpotsCount,
                    icon: const Icon(Icons.info),
                    label: const Text('Test DB'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _startMigration,
                    icon: _running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_running ? 'Running...' : 'Start Migration'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSpotsCount() async {
    try {
      final result = await context.read<GeocodingService>().testSpotsCount();
      if (!mounted) return;
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Total spots: ${result['totalSpots']}, Missing lat/lng: ${result['missingLatLng'] ?? 'Unknown'}'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get spots count'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startMigration() async {
    setState(() {
      _running = true;
    });
    try {
      final result = await context.read<GeocodingService>().migrateSpotsLatLng();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Latitude/longitude migration completed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
