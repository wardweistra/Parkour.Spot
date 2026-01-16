import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class DuplicateSpotsResultsScreen extends StatefulWidget {
  final String runId;
  
  const DuplicateSpotsResultsScreen({
    super.key,
    required this.runId,
  });

  @override
  State<DuplicateSpotsResultsScreen> createState() => _DuplicateSpotsResultsScreenState();
}

class _DuplicateSpotsResultsScreenState extends State<DuplicateSpotsResultsScreen> {
  final Set<int> _collapsedPairs = {}; // Track which pairs are collapsed
  String? _lastLoadedRunId; // Track which runId we last loaded collapsed pairs for
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateCollapsedPairs(String runId, Set<int> collapsedPairs) async {
    try {
      await FirebaseFirestore.instance
          .collection('duplicateDetectionResults')
          .doc(runId)
          .update({
        'collapsedPairs': collapsedPairs.toList(),
      });
    } catch (e) {
      // Silently fail - this is not critical functionality
      debugPrint('Failed to save collapsed pairs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate Spot Results')),
        body: const Center(
          child: Text('Administrator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Spot Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/duplicate-spots'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('duplicateDetectionResults')
            .doc(widget.runId)
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
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final pairsFound = stats['pairsFound'] as int? ?? 0;
          final spotsChecked = stats['spotsChecked'] as int? ?? 0;
          final sourceName = data['sourceName'] as String? ?? 'Unknown';
          
          // Load collapsed pairs from Firestore if available and runId changed
          if (_lastLoadedRunId != widget.runId) {
            final collapsedPairsData = data['collapsedPairs'] as List<dynamic>?;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _lastLoadedRunId != widget.runId) {
                setState(() {
                  if (collapsedPairsData != null) {
                    final savedCollapsedPairs = collapsedPairsData
                        .map((e) => e as int)
                        .toSet();
                    _collapsedPairs.clear();
                    _collapsedPairs.addAll(savedCollapsedPairs);
                  } else {
                    // No saved collapsed pairs
                    _collapsedPairs.clear();
                  }
                  _lastLoadedRunId = widget.runId;
                });
              }
            });
          }

          return Column(
            children: [
              // Header with stats
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Found $pairsFound potential duplicate pair${pairsFound == 1 ? '' : 's'} (checked $spotsChecked spots)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Results list
              Expanded(
                child: pairs.isEmpty
                    ? const Center(
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
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        key: PageStorageKey<String>('duplicate-results-${widget.runId}'),
                        padding: const EdgeInsets.all(16),
                        itemCount: pairs.length,
                        itemBuilder: (context, index) {
                          final pair = pairs[index] as Map<String, dynamic>;
                          final spot1 = pair['spot1'] as Map<String, dynamic>;
                          final spot2 = pair['spot2'] as Map<String, dynamic>;
                          final distanceMeters = pair['distanceMeters'] as int? ?? 0;
                          final isCollapsed = _collapsedPairs.contains(index);

                          return Card(
                            key: ValueKey('pair-$index'),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Checkbox and Distance header row
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isCollapsed,
                                        onChanged: (value) {
                                          // Update local state first
                                          final newCollapsedPairs = Set<int>.from(_collapsedPairs);
                                          if (value == true) {
                                            newCollapsedPairs.add(index);
                                          } else {
                                            newCollapsedPairs.remove(index);
                                          }
                                          
                                          // Update state without causing full rebuild
                                          setState(() {
                                            _collapsedPairs.clear();
                                            _collapsedPairs.addAll(newCollapsedPairs);
                                          });
                                          
                                          // Persist to Firestore asynchronously
                                          _updateCollapsedPairs(widget.runId, newCollapsedPairs);
                                        },
                                      ),
                                      Expanded(
                                        child: Container(
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
                                      ),
                                    ],
                                  ),
                                  if (!isCollapsed) ...[
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
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
