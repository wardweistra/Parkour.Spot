import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/spot.dart';

enum ExploreEntityPickerMode { spotsOnly, eventsOnly, spotsAndEvents }

class ExploreEntityPickerConfig {
  const ExploreEntityPickerConfig({
    required this.mode,
    this.allowMultiple = false,
    this.excludeSpotIds = const {},
    this.excludeEventIds = const {},
    this.preselectedSpotIds = const {},
    this.preselectedSpots = const [],
    this.initialCenter,
    this.allowExternalSources = false,
  });

  final ExploreEntityPickerMode mode;
  final bool allowMultiple;
  final Set<String> excludeSpotIds;
  final Set<String> excludeEventIds;
  final Set<String> preselectedSpotIds;
  final List<Spot> preselectedSpots;
  final LatLng? initialCenter;
  final bool allowExternalSources;

  bool get includesSpots =>
      mode == ExploreEntityPickerMode.spotsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents;

  bool get includesEvents =>
      mode == ExploreEntityPickerMode.eventsOnly ||
      mode == ExploreEntityPickerMode.spotsAndEvents;
}
