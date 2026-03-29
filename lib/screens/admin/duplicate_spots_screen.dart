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
  bool _hideCheckedResults = true; // Hide checked results by default

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
          context.push('/moderator/duplicate-spots/$runId');
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
    final authService = context.watch<AuthService>();
    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate Spots')),
        body: const Center(
          child: Text('Moderator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Spot Detection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/moderator');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Instructions section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to use Duplicate Spot Detection',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a source from the dropdown below and click "Find Duplicates" to scan for potential duplicate spots within 50 meters of each other. The system will check spots from the selected source against all other spots in the database. Review the results to identify and merge duplicate entries.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                      initialValue: _selectedSourceId,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Hide checked',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Switch(
                      value: _hideCheckedResults,
                      onChanged: (value) {
                        setState(() {
                          _hideCheckedResults = value;
                        });
                      },
                    ),
                  ],
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
          .limit(100)
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

        // Filter results based on hideCheckedResults setting
        final allDocs = snapshot.data!.docs;
        final filteredDocs = _hideCheckedResults
            ? allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isChecked = data['isChecked'] as bool? ?? false;
                return !isChecked;
              }).toList()
            : allDocs;

        final checkedCount = allDocs.length - filteredDocs.length;

        if (filteredDocs.isEmpty && allDocs.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  'All results checked',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toggle "Hide checked" to see all results',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (_hideCheckedResults && checkedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$checkedCount checked result${checkedCount == 1 ? '' : 's'} hidden. Toggle switch to show.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final stats = data['stats'] as Map<String, dynamic>? ?? {};
                  final pairsFound = stats['pairsFound'] as int? ?? 0;
                  final spotsChecked = stats['spotsChecked'] as int? ?? 0;
                  final sourceId = data['sourceId'] as String? ?? 'Unknown';
                  final sourceName = data['sourceName'] as String? ?? sourceId;
                  final createdAt = data['createdAt'] as Timestamp?;
                  final isChecked = data['isChecked'] as bool? ?? false;

                  return Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: isChecked,
                        onChanged: (value) async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('duplicateDetectionResults')
                                .doc(doc.id)
                                .update({
                              'isChecked': value ?? false,
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      title: Text(
                        sourceName,
                        style: TextStyle(
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Found $pairsFound pair${pairsFound == 1 ? '' : 's'} (checked $spotsChecked spots)'),
                          if (createdAt != null)
                            Text(
                              createdAt.toDate().toString().substring(0, 19),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        context.push('/moderator/duplicate-spots/${doc.id}');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
