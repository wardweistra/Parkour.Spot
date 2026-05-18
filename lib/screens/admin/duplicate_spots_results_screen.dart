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

  const DuplicateSpotsResultsScreen({super.key, required this.runId});

  @override
  State<DuplicateSpotsResultsScreen> createState() =>
      _DuplicateSpotsResultsScreenState();
}

class _DuplicateSpotsResultsScreenState
    extends State<DuplicateSpotsResultsScreen> {
  final Set<int> _collapsedPairs = {}; // Track which pairs are collapsed
  String?
  _lastLoadedRunId; // Track which runId we last loaded collapsed pairs for
  final ScrollController _scrollController = ScrollController();
  bool _hideCheckedPairs = true; // Hide checked pairs by default

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateCollapsedPairs(
    String runId,
    Set<int> collapsedPairs,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('duplicateDetectionResults')
          .doc(runId)
          .update({'collapsedPairs': collapsedPairs.toList()});
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
        body: const Center(child: Text('Moderator access required')),
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

          if (pairs.isEmpty) {
            return _buildEmptyPairsList(
              sourceName: sourceName,
              pairsFound: pairsFound,
              spotsChecked: spotsChecked,
            );
          }

          return _buildPairsList(
            pairs,
            sourceName: sourceName,
            pairsFound: pairsFound,
            spotsChecked: spotsChecked,
          );
        },
      ),
    );
  }

  Widget _buildPairsList(
    List<dynamic> pairs, {
    required String sourceName,
    required int pairsFound,
    required int spotsChecked,
  }) {
    // Filter pairs based on hideCheckedPairs setting, maintaining original order.
    final List<Map<String, dynamic>> displayPairs = [];

    for (int i = 0; i < pairs.length; i++) {
      if (_hideCheckedPairs && _collapsedPairs.contains(i)) {
        continue;
      }
      displayPairs.add({'pair': pairs[i] as Map<String, dynamic>, 'index': i});
    }

    final checkedCount = _collapsedPairs.length;
    final showHiddenCheckedBanner = _hideCheckedPairs && checkedCount > 0;
    final hasAllPairsChecked = _hideCheckedPairs && displayPairs.isEmpty;
    final headerItemsCount = 2;
    final staticItemsCount =
        headerItemsCount +
        (showHiddenCheckedBanner ? 1 : 0) +
        (hasAllPairsChecked ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      key: PageStorageKey<String>('duplicate-results-${widget.runId}'),
      padding: EdgeInsets.zero,
      itemCount:
          staticItemsCount + (hasAllPairsChecked ? 0 : displayPairs.length),
      itemBuilder: (context, listIndex) {
        if (listIndex == 0) {
          return _buildInstructionSection();
        }

        if (listIndex == 1) {
          return _buildHeaderSection(
            sourceName: sourceName,
            pairsFound: pairsFound,
            spotsChecked: spotsChecked,
          );
        }

        var pairListStartIndex = 2;
        if (showHiddenCheckedBanner) {
          if (listIndex == 2) {
            return _buildHiddenCheckedBanner(
              '$checkedCount checked pair${checkedCount == 1 ? '' : 's'} hidden. Toggle switch to show.',
            );
          }
          pairListStartIndex++;
        }

        if (hasAllPairsChecked) {
          return _buildStatusMessage(
            icon: Icons.check_circle,
            title: 'All pairs checked',
            subtitle: 'Toggle "Hide checked" to see all pairs',
          );
        }

        final pairData = displayPairs[listIndex - pairListStartIndex];
        final pair = pairData['pair'] as Map<String, dynamic>;
        final index = pairData['index'] as int;
        final spot1 = pair['spot1'] as Map<String, dynamic>;
        final spot2 = pair['spot2'] as Map<String, dynamic>;
        final distanceMeters = pair['distanceMeters'] as int? ?? 0;
        final isCollapsed = _collapsedPairs.contains(index);
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          key: ValueKey('pair-$index'),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isCollapsed,
                      onChanged: (value) {
                        final newCollapsedPairs = Set<int>.from(
                          _collapsedPairs,
                        );
                        if (value == true) {
                          newCollapsedPairs.add(index);
                        } else {
                          newCollapsedPairs.remove(index);
                        }

                        setState(() {
                          _collapsedPairs.clear();
                          _collapsedPairs.addAll(newCollapsedPairs);
                        });

                        _updateCollapsedPairs(widget.runId, newCollapsedPairs);
                      },
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.secondary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${distanceMeters}m apart',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
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
                  _buildSpotCard(spot1, 'Spot 1'),
                  const SizedBox(height: 12),
                  Center(
                    child: Icon(
                      Icons.compare_arrows,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSpotCard(spot2, 'Spot 2'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPairsList({
    required String sourceName,
    required int pairsFound,
    required int spotsChecked,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildInstructionSection(),
        _buildHeaderSection(
          sourceName: sourceName,
          pairsFound: pairsFound,
          spotsChecked: spotsChecked,
        ),
        _buildStatusMessage(
          icon: Icons.check_circle,
          title: 'No duplicate pairs found',
        ),
      ],
    );
  }

  Widget _buildInstructionSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reviewing Duplicate Pairs',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review each pair of spots to determine if they are duplicates. Click on a spot card to view its details, or use the location icon to locate it on the map. Check the checkbox when you\'ve reviewed a pair to mark it as checked. Use the "Hide checked" toggle to focus on pairs that still need review.',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection({
    required String sourceName,
    required int pairsFound,
    required int spotsChecked,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sourceName, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'Found $pairsFound potential duplicate pair${pairsFound == 1 ? '' : 's'} (checked $spotsChecked spots)',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
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
                  color: colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildHiddenCheckedBanner(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotCard(Map<String, dynamic> spot, String label) {
    final colorScheme = Theme.of(context).colorScheme;
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
                final uri = Uri.parse(
                  UrlService.generateExploreLocateUrl(spotId),
                );
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
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
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (spotId != null &&
                    MobileDetectionService.isRunningInBrowser) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
                if (hasImages) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.image,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 16)),
            if (address != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (city != null || countryCode != null) ...[
              const SizedBox(height: 2),
              Text(
                [city, countryCode].whereType<String>().join(', '),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (spotSourceName != null || spotSource != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.source,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    spotSourceName ?? spotSource ?? 'Unknown source',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 4),
              Text(
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
