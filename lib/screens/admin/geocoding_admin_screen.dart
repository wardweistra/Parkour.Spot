import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';

class GeocodingAdminScreen extends StatefulWidget {
  const GeocodingAdminScreen({super.key});

  @override
  State<GeocodingAdminScreen> createState() => _GeocodingAdminScreenState();
}

class _GeocodingAdminScreenState extends State<GeocodingAdminScreen> {
  Map<String, dynamic>? _lastResult;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Geocoding')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    final geocodingService = context.watch<GeocodingService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geocode Missing Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _startGeocoding,
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
                    Text('• Finds all spots where any of address, city, or country are empty'),
                    Text('• Reverse geocodes coordinates to get address, city, country code'),
                    Text('• Updates each spot with the fetched values'),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                        _lastResult!['message']?.toString() ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      if (_lastResult!['stats'] is Map) ...[
                        // Overview stats
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Total Spots',
                                      value: _lastResult!['stats']['totalSpots']?.toString() ?? '0',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Candidates',
                                      value: _lastResult!['stats']['totalCandidates']?.toString() ?? '0',
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Processing results
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Processing Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _StatChip(
                                    label: 'Processed',
                                    value: _lastResult!['stats']['processed']?.toString() ?? '0',
                                    color: Colors.blue,
                                  ),
                                  _StatChip(
                                    label: 'Updated',
                                    value: _lastResult!['stats']['updated']?.toString() ?? '0',
                                    color: Colors.green,
                                  ),
                                  _StatChip(
                                    label: 'Failed',
                                    value: _lastResult!['stats']['failed']?.toString() ?? '0',
                                    color: Colors.red,
                                  ),
                                  _StatChip(
                                    label: 'Skipped',
                                    value: _lastResult!['stats']['skipped']?.toString() ?? '0',
                                    color: Colors.orange,
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
                          ),
                        ),
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
                    onPressed: _running ? null : _startGeocoding,
                    icon: _running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_running ? 'Running...' : 'Run geocoding'),
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
    setState(() {
      _running = true;
    });
    try {
      final result = await context.read<GeocodingService>().testSpotsCount();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test completed: ${result['message']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: ${result?['error'] ?? 'Unknown error'}'),
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

  Future<void> _startGeocoding() async {
    setState(() {
      _running = true;
    });
    try {
      final result = await context.read<GeocodingService>().geocodeMissingSpotAddresses();
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geocoding started/completed successfully')),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

