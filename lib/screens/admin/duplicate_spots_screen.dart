import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../services/sync_source_service.dart';
import '../../widgets/page_scaffold.dart';

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
    final syncSourceService = Provider.of<SyncSourceService>(
      context,
      listen: false,
    );
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
      return PageScaffold(
        title: 'Duplicate Spot Detection',
        scrollable: false,
        onBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/moderator');
          }
        },
        body: const Center(child: Text('Moderator access required')),
      );
    }

    return PageScaffold(
      title: 'Duplicate Spot Detection',
      scrollable: false,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/moderator');
        }
      },
      body: _buildPastRuns(),
    );
  }

  Widget _buildInstructionsSection() {
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
                  'How to use Duplicate Spot Detection',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a source from the dropdown below and click "Find Duplicates" to scan for potential duplicate spots within 50 meters of each other. The system will check spots from the selected source against all other spots in the database. Review the results to identify and merge duplicate entries.',
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

  Widget _buildControlsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
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
            label: Text(
              _isRunning ? 'Finding Duplicates...' : 'Find Duplicates',
            ),
          ),
          const SizedBox(height: 16),
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
                color: colorScheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildInstructionsSection(),
              _buildControlsSection(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildInstructionsSection(),
              _buildControlsSection(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Error: ${snapshot.error}')),
              ),
            ],
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final filteredDocs = _hideCheckedResults
            ? allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isChecked = data['isChecked'] as bool? ?? false;
                return !isChecked;
              }).toList()
            : allDocs;
        final checkedCount = allDocs.length - filteredDocs.length;
        final showHiddenCheckedBanner = _hideCheckedResults && checkedCount > 0;
        final hasNoRuns = allDocs.isEmpty;
        final hasAllRunsChecked = allDocs.isNotEmpty && filteredDocs.isEmpty;

        final staticItemsCount =
            2 +
            (showHiddenCheckedBanner ? 1 : 0) +
            ((hasNoRuns || hasAllRunsChecked) ? 1 : 0);

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount:
              staticItemsCount +
              ((hasNoRuns || hasAllRunsChecked) ? 0 : filteredDocs.length),
          itemBuilder: (context, index) {
            final colorScheme = Theme.of(context).colorScheme;
            if (index == 0) {
              return _buildInstructionsSection();
            }

            if (index == 1) {
              return _buildControlsSection();
            }

            var runsStartIndex = 2;
            if (showHiddenCheckedBanner) {
              if (index == 2) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$checkedCount checked result${checkedCount == 1 ? '' : 's'} hidden. Toggle switch to show.',
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
              runsStartIndex++;
            }

            if (hasNoRuns) {
              return _buildStatusMessage(
                icon: Icons.info_outline,
                title: 'No detection runs yet',
                subtitle:
                    'Select a source and click "Find Duplicates" to start',
              );
            }

            if (hasAllRunsChecked) {
              return _buildStatusMessage(
                icon: Icons.check_circle,
                title: 'All results checked',
                subtitle: 'Toggle "Hide checked" to see all results',
              );
            }

            final doc = filteredDocs[index - runsStartIndex];
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
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await FirebaseFirestore.instance
                          .collection('duplicateDetectionResults')
                          .doc(doc.id)
                          .update({'isChecked': value ?? false});
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to update: $e'),
                            backgroundColor: colorScheme.error,
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
                    color: isChecked ? colorScheme.onSurfaceVariant : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found $pairsFound pair${pairsFound == 1 ? '' : 's'} (checked $spotsChecked spots)',
                    ),
                    if (createdAt != null)
                      Text(
                        createdAt.toDate().toString().substring(0, 19),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
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
        );
      },
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
}
