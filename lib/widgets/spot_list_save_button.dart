import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/saved_spot_list_service.dart';
import '../services/snackbar_service.dart';
import 'spot_detail_quick_action_chip.dart';

enum _SpotListSaveAction { login, save, unsave, viewSaved }

/// Matches spot detail Save control: outlined chip (icon + label) + popup menu.
class SpotListSaveButton extends StatelessWidget {
  final String listId;

  const SpotListSaveButton({super.key, required this.listId});

  String get _loginRedirect =>
      '/login?redirectTo=${Uri.encodeComponent('/list/$listId')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Consumer2<AuthService, SavedSpotListService>(
      builder: (context, authService, savedSpotListService, _) {
        if (authService.isLoading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SpotDetailQuickActionChip(
                icon: Icons.bookmark_border,
                iconColor: colorScheme.onSurface.withValues(alpha: 0.38),
                label: l10n.spotDetailLoading,
                showSpinner: true,
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
                tooltip: l10n.spotListSaveTooltipSaveList,
                position: PopupMenuPosition.under,
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                splashRadius: 20,
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
                            l10n.spotListSaveSignInTitle,
                            style: menuTheme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.spotListSaveSignInBody,
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
                                l10n.spotDetailSaveMenuLogInOrCreate,
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
                child: SpotDetailQuickActionChip(
                  icon: Icons.bookmark_border,
                  iconColor: colorScheme.onSurface.withValues(alpha: 0.75),
                  label: l10n.spotDetailQuickActionSave,
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
            String chipLabel;
            if (isBusy) {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.38);
              tooltip = l10n.spotDetailSaveTooltipUpdating;
              chipLabel = l10n.spotDetailSaveTooltipUpdating;
            } else if (isSaved) {
              icon = Icons.bookmark;
              iconColor = colorScheme.primary;
              tooltip = l10n.spotListSaveTooltipSavedList;
              chipLabel = l10n.spotListSaveTooltipSavedList;
            } else {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.6);
              tooltip = l10n.spotListSaveTooltipSaveList;
              chipLabel = l10n.spotDetailQuickActionSave;
            }

            Future<void> handleAction(_SpotListSaveAction action) async {
              switch (action) {
                case _SpotListSaveAction.login:
                  return;
                case _SpotListSaveAction.save:
                  final ok = await savedSpotListService.saveList(listId);
                  if (context.mounted) {
                    if (ok) {
                      SnackbarService.showSuccess(
                        l10n.spotListSaveSavedToProfile,
                      );
                    } else {
                      SnackbarService.showError(
                        savedSpotListService.error ??
                            l10n.spotListSaveCouldNotSaveList,
                      );
                    }
                  }
                  return;
                case _SpotListSaveAction.unsave:
                  final ok = await savedSpotListService.unsaveList(listId);
                  if (context.mounted) {
                    if (ok) {
                      SnackbarService.showSuccess(
                        l10n.spotListSaveRemovedFromSavedLists,
                      );
                    } else {
                      SnackbarService.showError(
                        savedSpotListService.error ??
                            l10n.spotListSaveCouldNotRemoveList,
                      );
                    }
                  }
                  return;
                case _SpotListSaveAction.viewSaved:
                  if (!context.mounted) return;
                  context.push('/profile/lists');
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
                  borderRadius: BorderRadius.circular(
                    SpotDetailUi.surfaceRadius,
                  ),
                  splashRadius: 20,
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
                                  l10n.spotListSaveActionSaveList,
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
                                  l10n.spotListSaveActionRemoveFromSaved,
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
                                l10n.spotListSaveActionViewSavedLists,
                                style: menuTheme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: SpotDetailQuickActionChip(
                    icon: icon,
                    iconColor: iconColor,
                    label: chipLabel,
                    showSpinner: isBusy,
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
