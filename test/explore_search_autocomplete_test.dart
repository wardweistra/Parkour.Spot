import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/explore_search_autocomplete.dart';

void main() {
  test('formatSpotSuggestionLocation prefers city and country', () {
    final spot = Spot(
      name: 'Test',
      description: '',
      latitude: 0,
      longitude: 0,
      city: 'Paris',
      countryCode: 'fr',
    );

    expect(formatSpotSuggestionLocation(spot), 'Paris, FR');
  });

  test('zoomLevelForPlaceDetails uses country zoom for countries', () {
    expect(
      zoomLevelForPlaceDetails({'types': ['country']}),
      6.0,
    );
    expect(
      zoomLevelForPlaceDetails({'types': ['locality']}),
      12.0,
    );
  });
}
