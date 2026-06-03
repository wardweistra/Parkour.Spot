import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/parkour_event.dart';
import '../../models/spot.dart';

class ExploreEntityPickerResult {
  const ExploreEntityPickerResult.location(this.location)
    : spot = null,
      event = null;

  const ExploreEntityPickerResult.spot(this.spot)
    : location = null,
      event = null;

  const ExploreEntityPickerResult.event(this.event)
    : location = null,
      spot = null;

  final LatLng? location;
  final Spot? spot;
  final ParkourEvent? event;
}
