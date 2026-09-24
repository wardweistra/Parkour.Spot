import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import '../models/spot.dart';
import '../models/spot_list.dart';
import '../utils/event_location_utils.dart';
import 'spot_form/location_section.dart';

/// Exclusive where mode shown in the event Where section.
enum EventWhereUiMode { pin, spots, lists }

/// Maps collapsed event-where data to the UI mode control.
EventWhereUiMode? eventWhereUiModeFromKind(EventWhereKind kind) {
  return switch (kind) {
    EventWhereKind.pin => EventWhereUiMode.pin,
    EventWhereKind.spots => EventWhereUiMode.spots,
    EventWhereKind.list => EventWhereUiMode.lists,
    EventWhereKind.none => null,
  };
}

/// Asks before clearing the current where selection when changing modes.
///
/// Returns `true` when the user confirms the switch.
Future<bool> confirmClearEventWhereSelection(
  BuildContext context, {
  required EventWhereUiMode currentMode,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final message = switch (currentMode) {
    EventWhereUiMode.spots => l10n.addEventWhereSwitchClearsSpots,
    EventWhereUiMode.lists => l10n.addEventWhereSwitchClearsLists,
    EventWhereUiMode.pin => l10n.addEventWhereSwitchClearsLocation,
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return PointerInterceptor(
        child: AlertDialog(
          title: Text(l10n.addEventWhereSwitchTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.profileCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.addEventWhereSwitchConfirm),
            ),
          ],
        ),
      );
    },
  );
  return confirmed == true;
}

/// Shared Where section for Add event, Suggest edit, and Admin edit.
///
/// Presents three mutually exclusive doors—exact location, spots, or spot
/// lists—then the map preview and mode-specific status / actions.
class EventWhereSection extends StatelessWidget {
  const EventWhereSection({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.mapDisplaySpots,
    required this.currentLocation,
    required this.hasSelectedPin,
    required this.isGettingLocation,
    required this.isSatelliteView,
    required this.isLocationPermissionDenied,
    required this.blockMapPointers,
    required this.mapHeroTagPrefix,
    required this.onRefreshLocation,
    required this.onPickOnMap,
    required this.onToggleSatellite,
    required this.onMapCreated,
    required this.linkedSpots,
    required this.linkedLists,
    required this.onRemoveSpot,
    required this.onRemoveList,
    this.enabled = true,
    this.showRequiredIndicator = true,
    this.cardMargin,
    this.addressField,
  });

  final EventWhereUiMode mode;
  final ValueChanged<EventWhereUiMode> onModeChanged;
  final List<Spot> mapDisplaySpots;
  final LatLng? currentLocation;
  /// True when an exact-location pin is set (not merely GPS map center).
  final bool hasSelectedPin;
  final bool isGettingLocation;
  final bool isSatelliteView;
  final bool isLocationPermissionDenied;
  final bool blockMapPointers;
  final String mapHeroTagPrefix;
  final VoidCallback onRefreshLocation;
  final VoidCallback onPickOnMap;
  final ValueChanged<bool> onToggleSatellite;
  final void Function(GoogleMapController) onMapCreated;
  final List<Spot> linkedSpots;
  final List<SpotList> linkedLists;
  final void Function(Spot spot) onRemoveSpot;
  final void Function(SpotList list) onRemoveList;
  final bool enabled;
  final bool showRequiredIndicator;
  final EdgeInsetsGeometry? cardMargin;
  final Widget? addressField;

  bool get _hasPin => mode == EventWhereUiMode.pin && hasSelectedPin;
  bool get _hasSpots =>
      mode == EventWhereUiMode.spots && linkedSpots.isNotEmpty;
  bool get _hasLists =>
      mode == EventWhereUiMode.lists && linkedLists.isNotEmpty;
  bool get _hasSelection => _hasPin || _hasSpots || _hasLists;

  String _pickOnMapHint(AppLocalizations l10n) {
    return switch (mode) {
      EventWhereUiMode.pin => l10n.addEventChooseOnMapHint,
      EventWhereUiMode.spots => l10n.addEventChooseSpotsHint,
      EventWhereUiMode.lists => l10n.addEventChooseListsHint,
    };
  }

  String _emptyStatus(AppLocalizations l10n) {
    return switch (mode) {
      EventWhereUiMode.pin => l10n.addEventLocationNotSet,
      EventWhereUiMode.spots => l10n.addEventSpotsNotSet,
      EventWhereUiMode.lists => l10n.addEventListsNotSet,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.addEventWhereSectionTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (showRequiredIndicator)
              Text(
                '*',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.addEventLocationSectionHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EventWhereUiMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment<EventWhereUiMode>(
                value: EventWhereUiMode.spots,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(
                  l10n.addEventWhereModeSpots,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                tooltip: l10n.addEventWhereModeSpots,
                enabled: enabled,
              ),
              ButtonSegment<EventWhereUiMode>(
                value: EventWhereUiMode.lists,
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: Text(
                  l10n.addEventWhereModeLists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                tooltip: l10n.addEventWhereModeLists,
                enabled: enabled,
              ),
              ButtonSegment<EventWhereUiMode>(
                value: EventWhereUiMode.pin,
                icon: const Icon(Icons.place_outlined, size: 18),
                label: Text(
                  l10n.addEventWhereModeLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                tooltip: l10n.addEventWhereModeLocation,
                enabled: enabled,
              ),
            ],
            selected: {mode},
            onSelectionChanged: enabled
                ? (next) {
                    if (next.isEmpty) return;
                    onModeChanged(next.first);
                  }
                : null,
          ),
        ),
        const SizedBox(height: 12),
        SpotLocationSection(
          embedded: true,
          sectionTitle: null,
          showRequiredIndicator: false,
          showSelectedPin: mode == EventWhereUiMode.pin && hasSelectedPin,
          showLocationDetails: false,
          mapHeroTagPrefix: mapHeroTagPrefix,
          linkedSpots: mapDisplaySpots,
          currentLocation: currentLocation,
          address: null,
          countryCode: null,
          isGettingLocation: isGettingLocation,
          isGeocoding: false,
          isSatelliteView: isSatelliteView,
          isLocationPermissionDenied: isLocationPermissionDenied,
          blockMapPointers: blockMapPointers || !enabled,
          pickOnMapHint: _pickOnMapHint(l10n),
          onRefreshLocation: onRefreshLocation,
          onPickOnMap: onPickOnMap,
          onToggleSatellite: onToggleSatellite,
          onMapCreated: onMapCreated,
        ),
        const SizedBox(height: 8),
        if (!_hasSelection)
          Text(
            _emptyStatus(l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else if (mode == EventWhereUiMode.pin)
          Text(
            l10n.addEventExactLocationSet,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (mode == EventWhereUiMode.spots)
                ...linkedSpots.map(
                  (spot) => Chip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text(
                      l10n.addEventLinkedSpotLabel(
                        spot.name.isNotEmpty ? spot.name : (spot.id ?? ''),
                      ),
                    ),
                    onDeleted: enabled ? () => onRemoveSpot(spot) : null,
                  ),
                ),
              if (mode == EventWhereUiMode.lists)
                ...linkedLists.map(
                  (list) => Chip(
                    avatar: const Icon(Icons.list_alt_outlined, size: 18),
                    label: Text(
                      l10n.addEventLinkedSpotListLabel(
                        list.name.isNotEmpty ? list.name : (list.id ?? ''),
                      ),
                    ),
                    onDeleted: enabled ? () => onRemoveList(list) : null,
                  ),
                ),
            ],
          ),
        if (mode == EventWhereUiMode.pin &&
            hasSelectedPin &&
            addressField != null) ...[
          const SizedBox(height: 12),
          addressField!,
        ],
      ],
    );

    return Card(
      margin: cardMargin,
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}
