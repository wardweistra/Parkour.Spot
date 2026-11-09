import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/widgets/explore_entity_picker/explore_entity_picker_config.dart';
import 'package:parkour_spot/widgets/explore_entity_picker/explore_entity_picker_screen.dart';

Spot _spot(String id) => Spot(
  id: id,
  name: id,
  description: '',
  latitude: 1,
  longitude: 2,
);

void main() {
  test('multi-spot spotsOnly seeds initialSpots', () {
    final spots = [_spot('a'), _spot('b')];
    final seeded = seedSelectedSpotsForPicker(
      ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
        allowMultipleSpots: true,
        initialSpots: spots,
      ),
    );
    expect(seeded.map((s) => s.id), ['a', 'b']);
  });

  test('spotsOnly without allowMultipleSpots ignores initialSpots', () {
    final seeded = seedSelectedSpotsForPicker(
      ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
        initialSpots: [_spot('a')],
      ),
    );
    expect(seeded, isEmpty);
  });

  test('eventWhere seeds collapsed initialSpots', () {
    final seeded = seedSelectedSpotsForPicker(
      ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.eventWhere,
        initialSpots: [_spot('a'), _spot('b')],
      ),
    );
    expect(seeded.map((s) => s.id), ['a', 'b']);
  });
}
