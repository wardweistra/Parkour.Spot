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
import '../../services/web_push_subscription_service.dart';
import '../../utils/location_permission_utils.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';

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
                final lastKnown = locations
                    .where((loc) => loc.isLastKnown)
                    .firstOrNull;
                final noActiveSaved =
                    saved.isEmpty || saved.every((loc) => !loc.enabled);
                final showNoLocationAlertsMessage =
                    !shareLastKnown && noActiveSaved;
                return Column(
                  children: [
                    _LastKnownLocationRow(
                      shareEnabled: shareLastKnown,
                      lastKnown: lastKnown,
                      subtitle: _lastKnownSubtitle(
                        l10n,
                        shareEnabled: shareLastKnown,
                        lastKnown: lastKnown,
                      ),
                      onShareChanged: (enabled) => _setShareLastKnown(
                        context: context,
                        authService: authService,
                        locationsService: locationsService,
                        enabled: enabled,
                      ),
                      onToggleEnabled: () {
                        final known = lastKnown;
                        if (known == null) return;
                        locationsService.setLocationEnabled(
                          id: known.id,
                          enabled: !known.enabled,
                        );
                      },
                      onEdit: () {
                        final known = lastKnown;
                        if (known == null) return;
                        _showLocationEditorDialog(context, existing: known);
                      },
                    ),
                    if (saved.isNotEmpty) const Divider(),
                    ...saved.map(
                      (location) => _LocationOfInterestRow(
                        key: ValueKey(location.id),
                        location: location,
                        title:
                            location.label ??
                            l10n.profileLocationAlertsDefaultLabel,
                        subtitle: _locationSubtitle(l10n, location),
                        leadingIcon: Icons.place_outlined,
                        onToggleEnabled: () {
                          locationsService.setLocationEnabled(
                            id: location.id,
                            enabled: !location.enabled,
                          );
                        },
                        onEdit: () => _showLocationEditorDialog(
                          context,
                          existing: location,
                        ),
                        onDelete: () => _confirmDeleteSavedLocation(
                          context,
                          locationsService,
                          location,
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
                              style: Theme.of(context).textTheme.bodySmall
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
    final notifyNewSpotsNearby =
        authService.userProfile?.notifyNewSpotsNearby == true;
    final notifyCheckInsNearby =
        authService.userProfile?.notifyCheckInsNearby == true;
    final notifyTrainingPlansNearby =
        authService.userProfile?.notifyTrainingPlansNearby == true;
    final notifyEventsNearby =
        authService.userProfile?.notifyEventsNearby == true;
    final notifyTrainingPlanCheckInReminders =
        authService.userProfile?.notifyTrainingPlanCheckInReminders == true;
    final pushService = context.watch<WebPushSubscriptionService>();

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
                final lastKnown = locations
                    .where((loc) => loc.isLastKnown)
                    .firstOrNull;
                final noActiveSaved =
                    saved.isEmpty || saved.every((loc) => !loc.enabled);
                final lastKnownActive = lastKnown != null && lastKnown.enabled;
                final hasActiveLocation = lastKnownActive || !noActiveSaved;
                final canOptInNewSpotAlerts =
                    hasActiveLocation || notifyNewSpotsNearby;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationSettingsGroupHeader(
                      title:
                          l10n.profileNotificationSettingsThisDeviceGroupTitle,
                      helper:
                          l10n.profileNotificationSettingsThisDeviceGroupHelper,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.devices_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(l10n.profilePushNotificationsThisDeviceTitle),
                      subtitle: Text(
                        _buildPushDeviceSubtitle(l10n, pushService),
                      ),
                      trailing: Switch(
                        value: pushService.isSubscribed,
                        onChanged:
                            (!pushService.isSupported ||
                                pushService.isBusy ||
                                authService.currentUser == null)
                            ? null
                            : (enabled) async {
                                if (enabled) {
                                  await pushService.enableCurrentDevice();
                                } else {
                                  await pushService.disableCurrentDevice();
                                }
                              },
                      ),
                    ),
                    if (pushService.lastError != null &&
                        pushService.lastError!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.profilePushNotificationsError,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _NotificationSettingsGroupHeader(
                      title:
                          l10n.profileNotificationSettingsEveryDeviceGroupTitle,
                      helper: l10n
                          .profileNotificationSettingsEveryDeviceGroupHelper,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.fiber_new_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.profileLocationAlertsNotifyNewSpotsTitle,
                      ),
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
                      title: Text(
                        l10n.profileLocationAlertsNotifyNearbyCheckInsTitle,
                      ),
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
                        Icons.event_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(l10n.profileLocationAlertsNotifyEventsTitle),
                      subtitle: Text(
                        l10n.profileLocationAlertsNotifyEventsSubtitle,
                      ),
                      trailing: Switch(
                        value: notifyEventsNearby,
                        onChanged: canOptInNewSpotAlerts
                            ? (enabled) async {
                                await authService.updateNotifyEventsNearby(
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
                        Icons.alarm_on_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(l10n.profileTrainingPlanCheckInReminderTitle),
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

  String _buildPushDeviceSubtitle(
    AppLocalizations l10n,
    WebPushSubscriptionService pushService,
  ) {
    if (!pushService.isSupported) {
      return l10n.profilePushNotificationsUnsupported;
    }
    if (pushService.isBusy) {
      return l10n.profilePushNotificationsLoading;
    }
    switch (pushService.permissionState) {
      case WebPushPermissionState.denied:
        return l10n.profilePushNotificationsPermissionDenied;
      case WebPushPermissionState.notDetermined:
        return l10n.profilePushNotificationsPermissionNotDetermined;
      case WebPushPermissionState.authorized:
        return pushService.isSubscribed
            ? l10n.profilePushNotificationsEnabled
            : l10n.profilePushNotificationsPermissionGrantedButOff;
      case WebPushPermissionState.unknown:
        return l10n.profilePushNotificationsUnknown;
    }
  }

  String _locationSubtitle(AppLocalizations l10n, LocationOfInterest location) {
    final radius = l10n.profileLocationAlertsRadiusOption(
      location.alertRadiusKm,
    );
    final address = location.address?.trim();
    if (address != null && address.isNotEmpty) {
      return '$address · $radius';
    }
    return radius;
  }

  String _lastKnownSubtitle(
    AppLocalizations l10n, {
    required bool shareEnabled,
    required LocationOfInterest? lastKnown,
  }) {
    if (!shareEnabled) {
      return l10n.profileLocationAlertsShareLastKnownSubtitle;
    }
    if (lastKnown == null) {
      return l10n.profileLocationAlertsShareLastKnownOnSubtitle;
    }
    return l10n.profileLocationAlertsLastKnownActiveSubtitle(
      _locationSubtitle(l10n, lastKnown),
    );
  }

  Future<void> _setShareLastKnown({
    required BuildContext context,
    required AuthService authService,
    required UserLocationsOfInterestService locationsService,
    required bool enabled,
  }) async {
    final prefSaved = await authService.updateShareLastKnownLocationForAlerts(
      enabled,
    );
    if (!prefSaved || !context.mounted) return;
    await locationsService.setLastKnownEnabled(enabled);
    if (!context.mounted) return;
    if (!enabled) return;
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

  Future<void> _confirmDeleteSavedLocation(
    BuildContext context,
    UserLocationsOfInterestService locationsService,
    LocationOfInterest location,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.profileLocationAlertsDeleteTitle),
          content: Text(
            l10n.profileLocationAlertsDeleteMessage(
              location.label ?? l10n.profileLocationAlertsDefaultLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.profileCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.profileLocationAlertsDeleteConfirmButton),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      await locationsService.deleteSavedLocation(location.id);
    }
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
    var alertRadiusKm =
        existing?.alertRadiusKm ?? LocationOfInterest.defaultAlertRadiusKm;
    final isLastKnown = existing?.isLastKnown == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final dialogTitle = existing == null
                ? l10n.profileLocationAlertsDialogAddTitle
                : isLastKnown
                ? l10n.profileLocationAlertsDialogEditLastKnownTitle
                : l10n.profileLocationAlertsDialogEditTitle;
            return AlertDialog(
              title: Text(dialogTitle),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isLastKnown) ...[
                        TextField(
                          controller: labelController,
                          decoration: InputDecoration(
                            labelText:
                                l10n.profileLocationAlertsLabelFieldLabel,
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
                              final result =
                                  await ExploreEntityPickerScreen.show(
                                    dialogContext,
                                    config: ExploreEntityPickerConfig(
                                      mode:
                                          ExploreEntityPickerMode.locationOnly,
                                      initialLocation:
                                          initialLat != null &&
                                              initialLng != null
                                          ? LatLng(initialLat, initialLng)
                                          : null,
                                    ),
                                  );
                              final picked = result?.location;
                              if (picked != null) {
                                setDialogState(() {
                                  selectedLat = picked.latitude;
                                  selectedLng = picked.longitude;
                                  validationError = null;
                                  selectedAddress = null;
                                });
                                final details = await geo
                                    .geocodeCoordinatesDetailsSilently(
                                      picked.latitude,
                                      picked.longitude,
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
                      ],
                      if (selectedLat != null && selectedLng != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedAddress ??
                              '${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _AlertRadiusSelector(
                        value: alertRadiusKm,
                        onChanged: (km) =>
                            setDialogState(() => alertRadiusKm = km),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.profileCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    if (isLastKnown) {
                      final success = await service.setLastKnownAlertRadius(
                        alertRadiusKm,
                      );
                      if (success && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      return;
                    }
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
                            alertRadiusKm: alertRadiusKm,
                            address: selectedAddress,
                          )
                        : await service.updateSavedLocation(
                            id: existing.id,
                            label: label,
                            latitude: selectedLat!,
                            longitude: selectedLng!,
                            enabled: existing.enabled,
                            alertRadiusKm: alertRadiusKm,
                            address: selectedAddress,
                          );
                    if (success && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.profileLocationAlertsSaveButton),
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

class _NotificationSettingsGroupHeader extends StatelessWidget {
  const _NotificationSettingsGroupHeader({
    required this.title,
    required this.helper,
  });

  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          helper,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _LastKnownLocationRow extends StatelessWidget {
  const _LastKnownLocationRow({
    required this.shareEnabled,
    required this.lastKnown,
    required this.subtitle,
    required this.onShareChanged,
    required this.onToggleEnabled,
    required this.onEdit,
  });

  final bool shareEnabled;
  final LocationOfInterest? lastKnown;
  final String subtitle;
  final ValueChanged<bool> onShareChanged;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final location = lastKnown;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.my_location_outlined, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileLocationAlertsLastKnownLabel,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          if (shareEnabled && location != null) ...[
            IconButton(
              tooltip: location.enabled
                  ? l10n.profileLocationAlertsDisableTooltip
                  : l10n.profileLocationAlertsEnableTooltip,
              onPressed: onToggleEnabled,
              icon: Icon(
                location.enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
            ),
            IconButton(
              tooltip: l10n.profileLocationAlertsEditTooltip,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
          Semantics(
            label: l10n.profileLocationAlertsLastKnownLabel,
            child: Switch(value: shareEnabled, onChanged: onShareChanged),
          ),
        ],
      ),
    );
  }
}

class _LocationOfInterestRow extends StatelessWidget {
  const _LocationOfInterestRow({
    super.key,
    required this.location,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.onToggleEnabled,
    required this.onEdit,
    this.onDelete,
  });

  final LocationOfInterest location;
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(leadingIcon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: location.enabled
                ? l10n.profileLocationAlertsDisableTooltip
                : l10n.profileLocationAlertsEnableTooltip,
            onPressed: onToggleEnabled,
            icon: Icon(
              location.enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
          ),
          IconButton(
            tooltip: l10n.profileLocationAlertsEditTooltip,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: l10n.profileLocationAlertsDeleteTooltip,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _AlertRadiusSelector extends StatelessWidget {
  const _AlertRadiusSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = LocationOfInterest.normalizeAlertRadiusKm(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileLocationAlertsRadiusFieldLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final km in LocationOfInterest.allowedAlertRadiusKm)
                ButtonSegment<int>(
                  value: km,
                  label: Text(l10n.profileLocationAlertsRadiusOption(km)),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              onChanged(next.first);
            },
          ),
        ),
      ],
    );
  }
}
