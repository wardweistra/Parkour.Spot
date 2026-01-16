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
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final result = await spotService.findDuplicateSpots(
        sourceId: _selectedSourceId!,
      );

      if (mounted) {
        setState(() {
          _isRunning = false;
        });
        // Navigate to results page
        final runId = result['runId'] as String?;
        if (runId != null) {
          context.go('/admin/duplicate-spots/$runId');
        }
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
              ],
            ),
          ),
          // Results section
          Expanded(
            child: _buildPastRuns(),
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
                  context.go('/admin/duplicate-spots/${doc.id}');
                },
              ),
            );
          },
        );
      },
    );
  }

}
