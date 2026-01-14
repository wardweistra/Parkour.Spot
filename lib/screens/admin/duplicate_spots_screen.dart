import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../services/sync_source_service.dart';

class DuplicateSpotsScreen extends StatefulWidget {
  const DuplicateSpotsScreen({super.key});

  @override
  State<DuplicateSpotsScreen> createState() => _DuplicateSpotsScreenState();
}

class _DuplicateSpotsScreenState extends State<DuplicateSpotsScreen> {
  String? _selectedSourceId;
  bool _isRunning = false;
  String? _error;
  String? _currentRunId;
  int? _pairsFound;
  int? _spotsChecked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSyncSources();
    });
  }

  Future<void> _loadSyncSources() async {
    final syncSourceService = Provider.of<SyncSourceService>(context, listen: false);
    await syncSourceService.fetchSyncSources(includeInactive: true);
  }

  Future<void> _findDuplicates() async {
    if (_selectedSourceId == null) {
      setState(() {
        _error = 'Please select a source';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
      _currentRunId = null;
      _pairsFound = null;
      _spotsChecked = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final result = await spotService.findDuplicateSpots(
        sourceId: _selectedSourceId!,
      );

      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentRunId = result['runId'] as String?;
          _pairsFound = result['pairsFound'] as int?;
          _spotsChecked = result['spotsChecked'] as int?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _error = 'Failed to find duplicates: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate Spots')),
        body: const Center(
          child: Text('Administrator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Spot Detection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Controls section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Consumer<SyncSourceService>(
                  builder: (context, syncSourceService, _) {
                    final sources = syncSourceService.sources
                      ..sort((a, b) => a.name.compareTo(b.name));
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedSourceId,
                      decoration: const InputDecoration(
                        labelText: 'Select Source',
                        border: OutlineInputBorder(),
                      ),
                      items: sources.map((source) {
                        return DropdownMenuItem<String>(
                          value: source.id,
                          child: Text(source.name),
                        );
                      }).toList(),
                      onChanged: _isRunning
                          ? null
                          : (value) {
                              setState(() {
                                _selectedSourceId = value;
                                _currentRunId = null;
                              });
                            },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: (_isRunning || _selectedSourceId == null)
                      ? null
                      : _findDuplicates,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isRunning ? 'Finding Duplicates...' : 'Find Duplicates'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_currentRunId != null && _pairsFound != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Detection completed',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Found $_pairsFound potential duplicate pair${_pairsFound == 1 ? '' : 's'} (checked $_spotsChecked spots)',
                          style: TextStyle(color: Colors.green[900]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Results section
          Expanded(
            child: _currentRunId != null
                ? _buildResults(_currentRunId!)
                : _buildPastRuns(),
          ),
        ],
      ),
    );
  }

  Widget _buildPastRuns() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('duplicateDetectionResults')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No detection runs yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Select a source and click "Find Duplicates" to start',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final stats = data['stats'] as Map<String, dynamic>? ?? {};
            final pairsFound = stats['pairsFound'] as int? ?? 0;
            final spotsChecked = stats['spotsChecked'] as int? ?? 0;
            final sourceId = data['sourceId'] as String? ?? 'Unknown';
            final sourceName = data['sourceName'] as String? ?? sourceId;
            final createdAt = data['createdAt'] as Timestamp?;

            return Card(
              child: ListTile(
                title: Text(sourceName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Found $pairsFound pair${pairsFound == 1 ? '' : 's'} (checked $spotsChecked spots)'),
                    if (createdAt != null)
                      Text(
                        '${createdAt.toDate().toString().substring(0, 19)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() {
                    _currentRunId = doc.id;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResults(String runId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('duplicateDetectionResults')
          .doc(runId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Results not found'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final pairs = (data['pairs'] as List<dynamic>?) ?? [];

        if (pairs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No duplicate pairs found',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pairs.length,
          itemBuilder: (context, index) {
            final pair = pairs[index] as Map<String, dynamic>;
            final spot1 = pair['spot1'] as Map<String, dynamic>;
            final spot2 = pair['spot2'] as Map<String, dynamic>;
            final distanceMeters = pair['distanceMeters'] as int? ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${distanceMeters}m apart',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Spot 1
                    _buildSpotCard(spot1, 'Spot 1'),
                    const SizedBox(height: 12),
                    // Arrow
                    Center(
                      child: Icon(Icons.compare_arrows, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 12),
                    // Spot 2
                    _buildSpotCard(spot2, 'Spot 2'),
                    const SizedBox(height: 16),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Spot 1'),
                            onPressed: () {
                              final spotId = spot1['id'] as String?;
                              if (spotId != null) {
                                context.go('/spot/$spotId');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Spot 2'),
                            onPressed: () {
                              final spotId = spot2['id'] as String?;
                              if (spotId != null) {
                                context.go('/spot/$spotId');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpotCard(Map<String, dynamic> spot, String label) {
    final name = spot['name'] as String? ?? 'Unknown';
    final address = spot['address'] as String?;
    final city = spot['city'] as String?;
    final countryCode = spot['countryCode'] as String?;
    final spotSource = spot['spotSource'] as String?;
    final spotSourceName = spot['spotSourceName'] as String?;
    final hasImages = spot['hasImages'] as bool? ?? false;
    final latitude = spot['latitude'] as num?;
    final longitude = spot['longitude'] as num?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              if (hasImages) ...[
                const SizedBox(width: 8),
                Icon(Icons.image, size: 16, color: Colors.grey[600]),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
          if (city != null || countryCode != null) ...[
            const SizedBox(height: 2),
            Text(
              [city, countryCode].whereType<String>().join(', '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (spotSourceName != null || spotSource != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.source, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  spotSourceName ?? spotSource ?? 'Unknown source',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}
