import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/spot_list.dart';
import '../../services/auth_service.dart';
import '../../services/saved_spot_list_service.dart';
import '../../services/spot_list_service.dart';
import '../../widgets/create_spot_list_dialog.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_list_summary_tile.dart';

/// Private atlas: Want to visit, Been to, lists you create, lists you save.
class SpotListsHubScreen extends StatefulWidget {
  const SpotListsHubScreen({super.key});

  @override
  State<SpotListsHubScreen> createState() => _SpotListsHubScreenState();
}

class _SpotListsHubScreenState extends State<SpotListsHubScreen> {
  Future<List<SpotList>>? _ownedListsFuture;
  int _ownedListsLoadToken = 0;
  String? _loadedForUserId;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId != null && userId != _loadedForUserId) {
      _loadedForUserId = userId;
      _ownedListsFuture = context.read<SpotListService>().getUserSpotLists();
    }
  }

  void _reloadOwnedLists() {
    final spotListService = context.read<SpotListService>();
    setState(() {
      _ownedListsLoadToken++;
      _ownedListsFuture = spotListService.getUserSpotLists();
    });
  }

  Future<void> _createList() async {
    final listId = await showCreateSpotListDialog(context);
    if (!mounted || listId == null) return;
    await context.push('/list/$listId');
    if (mounted) _reloadOwnedLists();
  }

  void _openList(SpotList list) {
    final id = list.id;
    if (id == null) return;
    context.push('/list/$id').then((_) {
      if (mounted) _reloadOwnedLists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (!authService.isAuthenticated) {
          return PageScaffold(
            title: _l10n.publicProfileSpotLists,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _l10n.spotListsHubSignInPrompt,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent('/profile/lists')}',
                    ),
                    child: Text(_l10n.profileSignInButton),
                  ),
                ],
              ),
            ),
          );
        }

        final wantCount = authService.userProfile?.wantToVisit?.length ?? 0;
        final visitedCount = authService.userProfile?.visited?.length ?? 0;
        final trackingEmpty = wantCount == 0 && visitedCount == 0;
        final scheme = Theme.of(context).colorScheme;
        final muted = scheme.onSurface.withValues(alpha: 0.6);

        return PageScaffold(
          title: _l10n.publicProfileSpotLists,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HubTrackingRow(
                icon: Icons.bookmark_outlined,
                title: _l10n.spotDetailWantToVisit,
                count: wantCount,
                onTap: () => context.push('/profile/want-to-visit'),
              ),
              _HubTrackingRow(
                icon: Icons.check_circle_outline,
                title: _l10n.publicProfileBeenTo,
                count: visitedCount,
                onTap: () => context.push('/profile/visited'),
              ),
              if (trackingEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _l10n.publicProfileAddSpotsFromSpotDetailPages,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _HubSectionHeader(
                title: _l10n.publicProfileYours,
                action: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: _l10n.spotDetailCreateNewList,
                  onPressed: _createList,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SpotList>>(
                key: ValueKey(_ownedListsLoadToken),
                future: _ownedListsFuture ?? Future.value(const <SpotList>[]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _HubInlineError(
                      message: _l10n.spotListsHubCouldNotLoad,
                      onRetry: _reloadOwnedLists,
                    );
                  }
                  final lists = snapshot.data ?? [];
                  if (lists.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.list_outlined,
                            size: 40,
                            color: scheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _l10n.spotDetailNoListsYet,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: muted),
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            onPressed: _createList,
                            text: _l10n.publicProfileCreateYourFirstList,
                            width: double.infinity,
                            icon: Icons.add,
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: lists
                        .map(
                          (list) => SpotListSummaryTile(
                            list: list,
                            onTap: () => _openList(list),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              _SavedListsSection(onOpenList: _openList),
            ],
          ),
        );
      },
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  const _HubSectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _HubTrackingRow extends StatelessWidget {
  const _HubTrackingRow({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        l10n.exploreSpotCountShort(count),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}

class _HubInlineError extends StatelessWidget {
  const _HubInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.profileRetry),
          ),
        ],
      ),
    );
  }
}

class _SavedListsSection extends StatelessWidget {
  const _SavedListsSection({required this.onOpenList});

  final ValueChanged<SpotList> onOpenList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final savedSpotListService = context.watch<SavedSpotListService>();
    final spotListService = context.read<SpotListService>();
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return StreamBuilder<List<String>>(
      stream: savedSpotListService.watchSavedListIdsOrdered(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final ids = snapshot.data ?? [];
        if (ids.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HubSectionHeader(title: l10n.publicProfileSaved),
            const SizedBox(height: 8),
            FutureBuilder<List<SpotList>>(
              key: ValueKey(ids.join(',')),
              future: savedSpotListService.resolveSavedListIds(
                spotListService,
                ids,
              ),
              builder: (context, listSnap) {
                if (listSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final savedLists = listSnap.data ?? [];
                if (savedLists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Text(
                      l10n.publicProfileSavedListsUnavailable,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  );
                }
                return Column(
                  children: savedLists
                      .map(
                        (list) => SpotListSummaryTile(
                          list: list,
                          leading: Icon(
                            Icons.bookmark,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onTap: () => onOpenList(list),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
