import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/spot.dart';

enum ExploreEntityPickerMode {
  locationOnly,
  spotsOnly,
  eventsOnly,
  spotsAndEvents,
  eventWhere,
}

enum LocationPickerUsageTip { addSpot, addEvent }

class ExploreEntityPickerConfig {
  const ExploreEntityPickerConfig({
    required this.mode,
    this.excludeSpotIds = const {},
    this.excludeEventIds = const {},
    this.initialLocation,
    this.initialCenter,
    this.initialSpots = const [],
    this.cameraFitLocations = const [],
    this.linkedSpotListName,
    this.usageTip,
    this.allowExternalSources = false,
  });

  final ExploreEntityPickerMode mode;
  final Set<String> excludeSpotIds;
  final Set<String> excludeEventIds;
  final LatLng? initialLocation;
  final LatLng? initialCenter;
  final List<Spot> initialSpots;
  final List<LatLng> cameraFitLocations;
  final String? linkedSpotListName;
  final LocationPickerUsageTip? usageTip;
  final bool allowExternalSources;

  bool get isEventWhere => mode == ExploreEntityPickerMode.eventWhere;

  String? get trimmedLinkedSpotListName {
    final name = linkedSpotListName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  bool get includesLocationPin =>
      mode == ExploreEntityPickerMode.locationOnly || isEventWhere;

  bool get includesSpots =>
      mode == ExploreEntityPickerMode.spotsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents ||
      isEventWhere;

  bool get includesEvents =>
      mode == ExploreEntityPickerMode.eventsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents;
}
