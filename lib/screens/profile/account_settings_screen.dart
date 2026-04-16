import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/location_of_interest.dart';
import '../../services/auth_service.dart';
import '../../services/locale_preferences_service.dart';
import '../../services/user_locations_of_interest_service.dart';
import '../../utils/location_permission_utils.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSettingsTitle)),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    _buildLanguageCard(context),
                    const SizedBox(height: 16),
                    _buildLocationAlertsCard(context, authService),
                  ],
                ),
              ),
            ),
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
                  l10n.profileSettingsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.profileSettingsLanguageLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
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
            Text(
              'Location alerts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Control which locations are used for nearby check-in notifications.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share last known location'),
              subtitle: const Text(
                'Use your device location (when granted) to match nearby alerts.',
              ),
              value: shareLastKnown,
              onChanged: (enabled) async {
                final prefSaved = await authService
                    .updateShareLastKnownLocationForAlerts(enabled);
                if (!prefSaved || !context.mounted) return;
                await locationsService.setLastKnownEnabled(enabled);
                if (enabled) {
                  final position =
                      await LocationPermissionUtils.getCurrentPositionWithPermission(
                        context: context,
                        showErrorMessages: false,
                      );
                  if (position != null) {
                    await locationsService.upsertLastKnownLocation(
                      latitude: position.latitude,
                      longitude: position.longitude,
                    );
                  }
                }
              },
            ),
            const Divider(),
            Row(
              children: [
                Text(
                  'Saved locations',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showLocationEditorDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            StreamBuilder<List<LocationOfInterest>>(
              stream: locationsService.watchLocations(),
              builder: (context, snapshot) {
                final locations = snapshot.data ?? const <LocationOfInterest>[];
                final saved = locations
                    .where((loc) => !loc.isLastKnown)
                    .toList();
                if (saved.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'No saved locations yet. Add places like Home or Work.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }
                return Column(
                  children: saved
                      .map(
                        (location) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(location.label ?? 'Saved location'),
                          subtitle: Text(
                            '${location.latitude.toStringAsFixed(5)}, '
                            '${location.longitude.toStringAsFixed(5)}',
                          ),
                          leading: Icon(
                            Icons.place_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: location.enabled
                                    ? 'Disable'
                                    : 'Enable',
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
                                tooltip: 'Edit',
                                onPressed: () => _showLocationEditorDialog(
                                  context,
                                  existing: location,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () async {
                                  await locationsService.deleteSavedLocation(
                                    location.id,
                                  );
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
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
    final service = Provider.of<UserLocationsOfInterestService>(
      context,
      listen: false,
    );
    final labelController = TextEditingController(text: existing?.label ?? '');
    final latController = TextEditingController(
      text: existing?.latitude.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: existing?.longitude.toString() ?? '',
    );
    var enabled = existing?.enabled ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add location' : 'Edit location'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label',
                        hintText: 'Home',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    if (label.isEmpty || lat == null || lng == null) {
                      return;
                    }

                    final success = existing == null
                        ? await service.addSavedLocation(
                            label: label,
                            latitude: lat,
                            longitude: lng,
                            enabled: enabled,
                          )
                        : await service.updateSavedLocation(
                            id: existing.id,
                            label: label,
                            latitude: lat,
                            longitude: lng,
                            enabled: enabled,
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
    latController.dispose();
    lngController.dispose();
  }
}
