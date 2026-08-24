import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/spot.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_duplicate_changes_dialog.dart';

class ModeratorDuplicateSpotUpdatesScreen extends StatelessWidget {
  const ModeratorDuplicateSpotUpdatesScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/moderator');
    }
  }

  Future<void> _review(BuildContext context, Spot spot) async {
    await reviewSpotDuplicateChanges(context: context, duplicateSpot: spot);
  }

  Future<void> _dismiss(BuildContext context, Spot spot) async {
    await reviewSpotDuplicateChanges(
      context: context,
      duplicateSpot: spot,
      dismissWithoutDialog: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context)!;

    if (!authService.isAuthenticated) {
      return PageScaffold(
        title: l10n.spotDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Sign in required')),
      );
    }

    if (authService.isLoading) {
      return PageScaffold(
        title: l10n.spotDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasModeratorAccess = authService.isModerator || authService.isAdmin;
    if (!hasModeratorAccess) {
      return PageScaffold(
        title: l10n.spotDuplicateChangesQueueTitle,
        scrollable: false,
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Moderator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spotDuplicateChangesQueueTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: StreamBuilder<List<Spot>>(
        stream: context.read<SpotService>().watchDuplicatePendingChangeSpots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final spots = snapshot.data!;
          if (spots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_all_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.spotDuplicateChangesQueueEmpty),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: spots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final spot = spots[index];
              return _DuplicateSpotUpdateCard(
                spot: spot,
                onReview: () => _review(context, spot),
                onDismiss: () => _dismiss(context, spot),
              );
            },
          );
        },
      ),
    );
  }
}

class _DuplicateSpotUpdateCard extends StatelessWidget {
  const _DuplicateSpotUpdateCard({
    required this.spot,
    required this.onReview,
    required this.onDismiss,
  });

  final Spot spot;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final subtitleParts = <String>[
      if (spot.spotSourceName != null && spot.spotSourceName!.trim().isNotEmpty)
        spot.spotSourceName!.trim(),
      if (spot.city != null && spot.city!.trim().isNotEmpty) spot.city!.trim(),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: spot.id == null
                        ? null
                        : () => context.push('/spot/${spot.id}'),
                    child: Text(spot.name, style: theme.textTheme.titleMedium),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: colors.onTertiaryContainer,
                  ),
                  label: Text(l10n.spotDuplicateChangesChip),
                  backgroundColor: colors.tertiaryContainer,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitleParts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(l10n.spotDuplicateChangesReview),
                ),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.spotDuplicateChangesDismiss),
                ),
                FilledButton.tonalIcon(
                  onPressed: spot.id == null
                      ? null
                      : () => context.push('/spot/${spot.id}'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.spotDuplicateChangesOpenSpot),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
