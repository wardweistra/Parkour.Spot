import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/saved_spot_list_service.dart';
import '../services/snackbar_service.dart';

enum _SpotListSaveAction { login, save, unsave, viewSaved }

/// Matches spot detail [Save] control: 44×44 circular bookmark + popup menu.
class SpotListSaveButton extends StatelessWidget {
  final String listId;

  const SpotListSaveButton({super.key, required this.listId});

  String get _loginRedirect =>
      '/login?redirectTo=${Uri.encodeComponent('/list/$listId')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer2<AuthService, SavedSpotListService>(
      builder: (context, authService, savedSpotListService, _) {
        if (authService.isLoading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (!authService.isAuthenticated) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<_SpotListSaveAction>(
                tooltip: 'Save list',
                position: PopupMenuPosition.under,
                borderRadius: BorderRadius.circular(22),
                splashRadius: 22,
                onSelected: (action) {
                  if (action == _SpotListSaveAction.login && context.mounted) {
                    context.go(_loginRedirect);
                  }
                },
                itemBuilder: (menuContext) {
                  final menuTheme = Theme.of(menuContext);
                  return <PopupMenuEntry<_SpotListSaveAction>>[
                    PopupMenuItem<_SpotListSaveAction>(
                      value: _SpotListSaveAction.login,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sign in to save lists',
                            style: menuTheme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save someone else’s spot list to your profile so you can open it again later.',
                            style: menuTheme.textTheme.bodySmall?.copyWith(
                              color: menuTheme.colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.login,
                                size: 20,
                                color: menuTheme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Log in or create account',
                                style: menuTheme.textTheme.labelLarge?.copyWith(
                                  color: menuTheme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_border,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return StreamBuilder<bool>(
          stream: savedSpotListService.watchIsSaved(listId),
          initialData: false,
          builder: (context, snapshot) {
            final isSaved = snapshot.data ?? false;
            final isBusy = savedSpotListService.isLoading;

            IconData icon;
            Color? iconColor;
            String tooltip;
            if (isBusy) {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.38);
              tooltip = 'Updating…';
            } else if (isSaved) {
              icon = Icons.bookmark;
              iconColor = colorScheme.primary;
              tooltip = 'Saved list';
            } else {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.6);
              tooltip = 'Save list';
            }

            Future<void> handleAction(_SpotListSaveAction action) async {
              switch (action) {
                case _SpotListSaveAction.login:
                  return;
                case _SpotListSaveAction.save:
                  final ok = await savedSpotListService.saveList(listId);
                  if (context.mounted) {
                    if (ok) {
                      SnackbarService.showSuccess('List saved to your profile');
                    } else {
                      SnackbarService.showError(
                        savedSpotListService.error ?? 'Could not save list',
                      );
                    }
                  }
                  return;
                case _SpotListSaveAction.unsave:
                  final ok = await savedSpotListService.unsaveList(listId);
                  if (context.mounted) {
                    if (ok) {
                      SnackbarService.showSuccess('Removed from saved lists');
                    } else {
                      SnackbarService.showError(
                        savedSpotListService.error ?? 'Could not remove list',
                      );
                    }
                  }
                  return;
                case _SpotListSaveAction.viewSaved:
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final uid = auth.currentUser?.uid;
                  if (uid == null || !context.mounted) return;
                  final profile = auth.userProfile;
                  final path = profile?.username?.isNotEmpty == true
                      ? '/user/${profile!.username}'
                      : '/user/$uid';
                  context.push('$path?section=saved-lists');
                  return;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<_SpotListSaveAction>(
                  enabled: !isBusy,
                  tooltip: tooltip,
                  position: PopupMenuPosition.under,
                  borderRadius: BorderRadius.circular(22),
                  splashRadius: 22,
                  onSelected: handleAction,
                  itemBuilder: (menuContext) {
                    final menuTheme = Theme.of(menuContext);
                    final primary = menuTheme.colorScheme.primary;
                    return <PopupMenuEntry<_SpotListSaveAction>>[
                      if (!isSaved)
                        PopupMenuItem<_SpotListSaveAction>(
                          value: _SpotListSaveAction.save,
                          child: Row(
                            children: [
                              Icon(
                                Icons.bookmark_add_outlined,
                                size: 20,
                                color: primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Save list',
                                  style: menuTheme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        PopupMenuItem<_SpotListSaveAction>(
                          value: _SpotListSaveAction.unsave,
                          child: Row(
                            children: [
                              Icon(
                                Icons.bookmark_remove_outlined,
                                size: 20,
                                color: primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Remove from saved',
                                  style: menuTheme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_SpotListSaveAction>(
                        value: _SpotListSaveAction.viewSaved,
                        child: Row(
                          children: [
                            Icon(
                              Icons.list_alt_outlined,
                              size: 20,
                              color: primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'View saved lists',
                                style: menuTheme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isBusy
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
