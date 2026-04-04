import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/url_service.dart';
import '../../widgets/page_scaffold.dart';

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
  bool _hideCheckedPairs = true; // Hide checked pairs by default

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
    final authService = context.watch<AuthService>();
    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return PageScaffold(
        title: 'Duplicate Spot Results',
        scrollable: false,
        onBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/moderator/duplicate-spots');
          }
        },
        body: const Center(
          child: Text('Moderator access required'),
        ),
      );
    }

    return PageScaffold(
      title: 'Duplicate Spot Results',
      scrollable: false,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/moderator/duplicate-spots');
        }
      },
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
                            'Reviewing Duplicate Pairs',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review each pair of spots to determine if they are duplicates. Click on a spot card to view its details, or use the location icon to locate it on the map. Check the checkbox when you\'ve reviewed a pair to mark it as checked. Use the "Hide checked" toggle to focus on pairs that still need review.',
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
              // Header with stats
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sourceName,
                                style: const TextStyle(
                                  fontSize: 18,
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
                              value: _hideCheckedPairs,
                              onChanged: (value) {
                                setState(() {
                                  _hideCheckedPairs = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
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
                    : _buildPairsList(pairs),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPairsList(List<dynamic> pairs) {
    // Filter pairs based on hideCheckedPairs setting, maintaining original order
    final List<Map<String, dynamic>> displayPairs = [];
    
    for (int i = 0; i < pairs.length; i++) {
      // If hiding checked pairs, skip collapsed ones; otherwise include all
      if (_hideCheckedPairs && _collapsedPairs.contains(i)) {
        continue;
      }
      displayPairs.add({
        'pair': pairs[i] as Map<String, dynamic>,
        'index': i,
      });
    }
    
    final int checkedCount = _collapsedPairs.length;
    final int visibleCount = displayPairs.length;
    
    if (_hideCheckedPairs && visibleCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'All pairs checked',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Toggle "Hide checked" to see all pairs',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        if (_hideCheckedPairs && checkedCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$checkedCount checked pair${checkedCount == 1 ? '' : 's'} hidden. Toggle switch to show.',
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
            controller: _scrollController,
            key: PageStorageKey<String>('duplicate-results-${widget.runId}'),
            padding: EdgeInsets.zero,
            itemCount: displayPairs.length,
            itemBuilder: (context, listIndex) {
              final pairData = displayPairs[listIndex];
              final pair = pairData['pair'] as Map<String, dynamic>;
              final index = pairData['index'] as int;
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
    final spotId = spot['id'] as String?;

    return InkWell(
      onTap: spotId != null
          ? () async {
              // Open in new tab when running in browser; use in-app nav when PWA
              if (MobileDetectionService.isRunningInBrowser) {
                final uri = Uri.parse(UrlService.generateExploreLocateUrl(spotId));
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } else {
                context.go('/explore?locateSpotId=$spotId');
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
                    color: Colors.grey[600],
                  ),
                ),
                if (spotId != null && MobileDetectionService.isRunningInBrowser) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new, size: 14, color: Colors.grey[600]),
                ],
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
      ),
    );
  }
}
