import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';

class GeohashAdminScreen extends StatefulWidget {
  const GeohashAdminScreen({super.key});

  @override
  State<GeohashAdminScreen> createState() => _GeohashAdminScreenState();
}

class _GeohashAdminScreenState extends State<GeohashAdminScreen> {
  Map<String, dynamic>? _lastResult;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Geohash Calculation')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    final geocodingService = context.watch<GeocodingService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geohash Calculation'),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _startGeohashCalculation,
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
                    Text('• Finds all spots where geohash field is empty or null'),
                    Text('• Calculates geohash from latitude and longitude coordinates'),
                    Text('• Updates each spot with the calculated geohash value'),
                    SizedBox(height: 8),
                    Text('Note: Geohash enables efficient proximity searches and spatial indexing.', 
                         style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (geocodingService.error != null)
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    geocodingService.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (_lastResult != null) ...[
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastResult!['message'] ?? 'Geohash calculation completed',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_lastResult!['stats'] != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Results:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              label: 'Total',
                              value: _lastResult!['stats']['total'],
                              color: Colors.blue,
                            ),
                            _StatChip(
                              label: 'Processed',
                              value: _lastResult!['stats']['processed'],
                              color: Colors.orange,
                            ),
                            _StatChip(
                              label: 'Updated',
                              value: _lastResult!['stats']['updated'],
                              color: Colors.green,
                            ),
                            _StatChip(
                              label: 'Failed',
                              value: _lastResult!['stats']['failed'],
                              color: Colors.red,
                            ),
                            _StatChip(
                              label: 'Skipped',
                              value: _lastResult!['stats']['skipped'],
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        if (_lastResult!['stats']['successRate'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Success Rate: ${_lastResult!['stats']['successRate']}',
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
                    onPressed: _running ? null : _startGeohashCalculation,
                    icon: _running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_on),
                    label: Text(_running ? 'Running...' : 'Calculate Geohashes'),
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
            content: Text('Total spots: ${result['totalSpots']}, Missing geohash: ${result['missingGeohash'] ?? 'Unknown'}'),
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

  Future<void> _startGeohashCalculation() async {
    setState(() {
      _running = true;
    });
    try {
      final result = await context.read<GeocodingService>().calculateMissingSpotGeohashes();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geohash calculation started/completed successfully')),
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
  final dynamic value;
  final Color? color;

  const _StatChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color?.withValues(alpha: 0.2),
      label: Text(
        '$label: ${value ?? '-'}',
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
