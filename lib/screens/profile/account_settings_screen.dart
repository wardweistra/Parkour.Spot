import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/location_of_interest.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/locale_preferences_service.dart';
import '../../services/user_locations_of_interest_service.dart';
import '../../utils/location_permission_utils.dart';
import '../../widgets/page_scaffold.dart';
import '../spots/location_picker_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PageScaffold(
      title: l10n.profileSettingsTitle,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/profile');
        }
      },
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          return Column(
            children: [
              _buildLanguageCard(context),
              const SizedBox(height: 16),
              _buildLocationAlertsCard(context, authService),
              const SizedBox(height: 16),
              _buildNotificationSettingsCard(context, authService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
    return Consumer<LocalePreferencesService>(
      builder: (context, localePrefs, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final selection = localePrefs.overrideLanguageCode ?? 'system';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileSettingsLanguageLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.profileSettingsLanguageDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ButtonTheme.fromButtonThemeData(
                    data: ButtonTheme.of(
                      context,
                    ).copyWith(alignedDropdown: false),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          focusColor: Colors.transparent,
                          hoverColor: scheme.onSurface.withValues(alpha: 0.06),
                          splashColor: scheme.onSurface.withValues(alpha: 0.10),
                          highlightColor: scheme.onSurface.withValues(
                            alpha: 0.06,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selection,
                            isExpanded: true,
                            isDense: true,
                            focusColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            items: [
                              DropdownMenuItem(
                                value: 'system',
                                child: Text(l10n.profileLanguageSystemDefault),
                              ),
                              ...LocalePreferencesService.supportedLanguageCodes()
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(
                                        LocalePreferencesService.nativeLanguageLabel(
                                          code,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: (value) async {
                              if (value == null) return;
                              if (value == 'system') {
                                await localePrefs.clearOverride();
                              } else {
                                await localePrefs.setOverride(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationAlertsCard(
    BuildContext context,
    AuthService authService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locationsService = Provider.of<UserLocationsOfInterestService>(
      context,
      listen: false,
    );
    final shareLastKnown =
        authService.userProfile?.shareLastKnownLocationForAlerts == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.profileLocationAlertsSavedLocationsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showLocationEditorDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.profileLocationAlertsAddLocationButton),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.profileLocationAlertsDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<LocationOfInterest>>(
              stream: locationsService.watchLocations(),
              builder: (context, snapshot) {
                final locations = snapshot.data ?? const <LocationOfInterest>[];
                final saved = locations
                    .where((loc) => !loc.isLastKnown)
                    .toList();
                final noActiveSaved =
                    saved.isEmpty || saved.every((loc) => !loc.enabled);
                final showNoLocationAlertsMessage =
                    !shareLastKnown && noActiveSaved;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.my_location_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.profileLocationAlertsShareLastKnownTitle,
                      ),
                      subtitle: Text(
                        l10n.profileLocationAlertsShareLastKnownSubtitle,
                      ),
                      trailing: Switch(
                        value: shareLastKnown,
                        onChanged: (enabled) async {
                          final prefSaved = await authService
                              .updateShareLastKnownLocationForAlerts(enabled);
                          if (!prefSaved || !context.mounted) return;
                          await locationsService.setLastKnownEnabled(enabled);
                          if (!context.mounted) return;
                          if (enabled) {
                            final position =
                                await LocationPermissionUtils.getCurrentPositionWithPermission(
                                  context: context,
                                  showErrorMessages: false,
                                );
                            if (position != null && context.mounted) {
                              await locationsService.upsertLastKnownLocation(
                                latitude: position.latitude,
                                longitude: position.longitude,
                              );
                            }
                          }
                        },
                      ),
                    ),
                    if (saved.isNotEmpty) const Divider(),
                    ...saved.map(
                      (location) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          location.label ??
                              l10n.profileLocationAlertsDefaultLabel,
                        ),
                        subtitle:
                            location.address != null &&
                                location.address!.isNotEmpty
                            ? Text(
                                location.address!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                              )
                            : null,
                        leading: Icon(
                          Icons.place_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: location.enabled
                                  ? l10n.profileLocationAlertsDisableTooltip
                                  : l10n.profileLocationAlertsEnableTooltip,
                              onPressed: () async {
                                await locationsService.setLocationEnabled(
                                  id: location.id,
                                  enabled: !location.enabled,
                                );
                              },
                              icon: Icon(
                                location.enabled
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  l10n.profileLocationAlertsEditTooltip,
                              onPressed: () => _showLocationEditorDialog(
                                context,
                                existing: location,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip:
                                  l10n.profileLocationAlertsDeleteTooltip,
                              onPressed: () async {
                                final shouldDelete =
                                    await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: Text(
                                        l10n.profileLocationAlertsDeleteTitle,
                                      ),
                                      content: Text(
                                        l10n.profileLocationAlertsDeleteMessage(
                                          location.label ??
                                              l10n
                                                  .profileLocationAlertsDefaultLabel,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: Text(l10n.profileCancel),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                          child: Text(
                                            l10n.profileLocationAlertsDeleteConfirmButton,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (shouldDelete == true) {
                                  await locationsService.deleteSavedLocation(
                                    location.id,
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showNoLocationAlertsMessage) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.profileLocationAlertsNoLocationsEnabledWarning,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.75),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard(
    BuildContext context,
    AuthService authService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locationsService = Provider.of<UserLocationsOfInterestService>(
      context,
      listen: false,
    );
    final shareLastKnown =
        authService.userProfile?.shareLastKnownLocationForAlerts == true;
    final notifyNewSpotsNearby =
        authService.userProfile?.notifyNewSpotsNearby == true;
    final notifyCheckInsNearby =
        authService.userProfile?.notifyCheckInsNearby == true;
    final notifyTrainingPlansNearby =
        authService.userProfile?.notifyTrainingPlansNearby == true;
    final notifyTrainingPlanCheckInReminders =
        authService.userProfile?.notifyTrainingPlanCheckInReminders == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileNotificationSettingsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<LocationOfInterest>>(
              stream: locationsService.watchLocations(),
              builder: (context, snapshot) {
                final locations = snapshot.data ?? const <LocationOfInterest>[];
                final saved = locations
                    .where((loc) => !loc.isLastKnown)
                    .toList(growable: false);
                final noActiveSaved =
                    saved.isEmpty || saved.every((loc) => !loc.enabled);
                final hasActiveLocation = shareLastKnown || !noActiveSaved;
                final canOptInNewSpotAlerts =
                    hasActiveLocation || notifyNewSpotsNearby;

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.fiber_new_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(l10n.profileLocationAlertsNotifyNewSpotsTitle),
                      subtitle: Text(
                        l10n.profileLocationAlertsNotifyNewSpotsSubtitle,
                      ),
                      trailing: Switch(
                        value: notifyNewSpotsNearby,
                        onChanged: canOptInNewSpotAlerts
                            ? (enabled) async {
                                await authService.updateNotifyNewSpotsNearby(
                                  enabled,
                                );
                              }
                            : null,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.how_to_reg_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(l10n.profileLocationAlertsNotifyNearbyCheckInsTitle),
                      subtitle: Text(
                        l10n.profileLocationAlertsNotifyNearbyCheckInsSubtitle,
                      ),
                      trailing: Switch(
                        value: notifyCheckInsNearby,
                        onChanged: canOptInNewSpotAlerts
                            ? (enabled) async {
                                await authService.updateNotifyCheckInsNearby(
                                  enabled,
                                );
                              }
                            : null,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.event_available_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.profileLocationAlertsNotifyTrainingPlansTitle,
                      ),
                      subtitle: Text(
                        l10n.profileLocationAlertsNotifyTrainingPlansSubtitle,
                      ),
                      trailing: Switch(
                        value: notifyTrainingPlansNearby,
                        onChanged: canOptInNewSpotAlerts
                            ? (enabled) async {
                                await authService
                                    .updateNotifyTrainingPlansNearby(enabled);
                              }
                            : null,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.alarm_on_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.profileTrainingPlanCheckInReminderTitle,
                      ),
                      subtitle: Text(
                        l10n.profileTrainingPlanCheckInReminderSubtitle,
                      ),
                      trailing: Switch(
                        value: notifyTrainingPlanCheckInReminders,
                        onChanged: (enabled) async {
                          await authService
                              .updateNotifyTrainingPlanCheckInReminders(
                            enabled,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationEditorDialog(
    BuildContext context, {
    LocationOfInterest? existing,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final service = Provider.of<UserLocationsOfInterestService>(
      context,
      listen: false,
    );
    final labelController = TextEditingController(text: existing?.label ?? '');
    String? validationError;
    double? selectedLat = existing?.latitude;
    double? selectedLng = existing?.longitude;
    String? selectedAddress = existing?.address;
    var enabled = existing?.enabled ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? l10n.profileLocationAlertsDialogAddTitle
                    : l10n.profileLocationAlertsDialogEditTitle,
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: l10n.profileLocationAlertsLabelFieldLabel,
                        hintText:
                            l10n.profileLocationAlertsLabelFieldPlaceholder,
                        errorText: validationError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final initialLat =
                              selectedLat ?? existing?.latitude;
                          final initialLng =
                              selectedLng ?? existing?.longitude;
                          final geo = Provider.of<GeocodingService>(
                            dialogContext,
                            listen: false,
                          );
                          final result = await Navigator.of(dialogContext).push<
                              LatLng?>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) => LocationPickerScreen(
                                initialLocation: initialLat != null &&
                                        initialLng != null
                                    ? LatLng(initialLat, initialLng)
                                    : null,
                              ),
                            ),
                          );
                          if (result != null) {
                            setDialogState(() {
                              selectedLat = result.latitude;
                              selectedLng = result.longitude;
                              validationError = null;
                              selectedAddress = null;
                            });
                            final details =
                                await geo.geocodeCoordinatesDetailsSilently(
                                  result.latitude,
                                  result.longitude,
                                );
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              selectedAddress = details['address'];
                            });
                          }
                        },
                        icon: const Icon(Icons.map),
                        label: Text(
                          selectedLat != null && selectedLng != null
                              ? l10n.spotDetailChangeLocationPicked
                              : l10n.spotDetailPickLocationOnMap,
                        ),
                      ),
                    ),
                    if (selectedLat != null && selectedLng != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedAddress ??
                              '${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.profileLocationAlertsEnabledLabel),
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.profileCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    if (label.isEmpty) {
                      setDialogState(() {
                        validationError =
                            l10n.profileLocationAlertsLabelRequired;
                      });
                      return;
                    }
                    if (selectedLat == null || selectedLng == null) {
                      setDialogState(() {
                        validationError =
                            l10n.profileLocationAlertsLocationRequired;
                      });
                      return;
                    }

                    final success = existing == null
                        ? await service.addSavedLocation(
                            label: label,
                            latitude: selectedLat!,
                            longitude: selectedLng!,
                            enabled: enabled,
                            address: selectedAddress,
                          )
                        : await service.updateSavedLocation(
                            id: existing.id,
                            label: label,
                            latitude: selectedLat!,
                            longitude: selectedLng!,
                            enabled: enabled,
                            address: selectedAddress,
                          );
                    if (success && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    labelController.dispose();
  }
}
