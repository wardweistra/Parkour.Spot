import '../../models/parkour_event.dart';
import '../../models/spot.dart';

class ExploreEntityPickerResult {
  const ExploreEntityPickerResult.spots(this.spots)
    : events = const <ParkourEvent>[];

  const ExploreEntityPickerResult.events(this.events)
    : spots = const <Spot>[];

  final List<Spot> spots;
  final List<ParkourEvent> events;
}
