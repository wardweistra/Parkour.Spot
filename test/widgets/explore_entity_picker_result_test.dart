import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/widgets/explore_entity_picker/explore_entity_picker_result.dart';

void main() {
  final spot = Spot(
    id: 'spot-1',
    name: 'Rail',
    description: '',
    latitude: 52.37,
    longitude: 4.89,
  );

  test('location result keeps spots empty', () {
    const location = LatLng(52.37, 4.89);
    final result = ExploreEntityPickerResult.location(location);

    expect(result.location, location);
    expect(result.spot, isNull);
    expect(result.spots, isEmpty);
    expect(result.event, isNull);
  });

  test('spot result keeps spots empty for single-select callers', () {
    final result = ExploreEntityPickerResult.spot(spot);

    expect(result.spot, spot);
    expect(result.spots, isEmpty);
    expect(result.location, isNull);
    expect(result.event, isNull);
  });

  test('spots result holds the working set without a pin', () {
    final result = ExploreEntityPickerResult.spots([spot]);

    expect(result.spots, [spot]);
    expect(result.spot, isNull);
    expect(result.location, isNull);
    expect(result.event, isNull);
  });
}
