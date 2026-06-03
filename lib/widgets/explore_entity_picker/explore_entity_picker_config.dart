import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ExploreEntityPickerMode {
  locationOnly,
  spotsOnly,
  eventsOnly,
  spotsAndEvents,
}

enum LocationPickerUsageTip { addSpot, addEvent }

class ExploreEntityPickerConfig {
  const ExploreEntityPickerConfig({
    required this.mode,
    this.excludeSpotIds = const {},
    this.excludeEventIds = const {},
    this.initialLocation,
    this.initialCenter,
    this.usageTip,
    this.allowExternalSources = false,
  });

  final ExploreEntityPickerMode mode;
  final Set<String> excludeSpotIds;
  final Set<String> excludeEventIds;
  final LatLng? initialLocation;
  final LatLng? initialCenter;
  final LocationPickerUsageTip? usageTip;
  final bool allowExternalSources;

  bool get includesLocationPin =>
      mode == ExploreEntityPickerMode.locationOnly;

  bool get includesSpots =>
      mode == ExploreEntityPickerMode.spotsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents;

  bool get includesEvents =>
      mode == ExploreEntityPickerMode.eventsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents;
}
