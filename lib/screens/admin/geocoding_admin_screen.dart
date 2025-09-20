import 'package:flutter/material.dart';
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
                color: Colors.red.withOpacity(0.1),
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
                      const Text('Last run', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_lastResult!['message']?.toString() ?? ''),
                      const SizedBox(height: 8),
                      if (_lastResult!['stats'] is Map)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _StatChip(label: 'Candidates', value: _lastResult!['stats']['totalCandidates']),
                            _StatChip(label: 'Processed', value: _lastResult!['stats']['processed']),
                            _StatChip(label: 'Updated', value: _lastResult!['stats']['updated']),
                            _StatChip(label: 'Failed', value: _lastResult!['stats']['failed']),
                            _StatChip(label: 'Skipped', value: _lastResult!['stats']['skipped']),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
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
      ),
    );
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

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value ?? '-'}'),
    );
  }
}

