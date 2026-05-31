import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/spot.dart';
import '../services/admin_events_service.dart';
import '../services/geocoding_service.dart';
import '../services/spot_service.dart';
import '../widgets/explore_entity_picker/explore_entity_picker_config.dart';

String formatSpotSuggestionLocation(Spot spot) {
  final parts = <String>[];
  if (spot.city != null && spot.city!.isNotEmpty) {
    parts.add(spot.city!);
  }
  if (spot.countryCode != null && spot.countryCode!.isNotEmpty) {
    parts.add(spot.countryCode!.toUpperCase());
  }
  return parts.join(', ');
}

String formatEventSuggestionLocation(Map<String, dynamic> event) {
  final parts = <String>[];
  final city = event['city'] as String?;
  final countryCode = event['countryCode'] as String?;
  if (city != null && city.isNotEmpty) parts.add(city);
  if (countryCode != null && countryCode.isNotEmpty) {
    parts.add(countryCode.toUpperCase());
  }
  return parts.join(', ');
}

double zoomLevelForPlaceDetails(Map<String, dynamic> details) {
  final types = details['types'] as List<dynamic>? ?? [];

  if (types.contains('country')) return 6.0;
  if (types.contains('administrative_area_level_1')) return 8.0;
  if (types.contains('administrative_area_level_2')) return 10.0;
  if (types.contains('locality') || types.contains('administrative_area_level_3')) {
    return 12.0;
  }
  if (types.contains('sublocality') || types.contains('neighborhood')) {
    return 13.0;
  }
  if (types.contains('establishment') || types.contains('point_of_interest')) {
    return 15.0;
  }
  return 13.5;
}

Future<List<Map<String, dynamic>>> buildExploreAutocompleteOptions({
  required String query,
  required ExploreEntityPickerConfig config,
  required GeocodingService geocoding,
  required SpotService spotService,
  required AdminEventsService eventsService,
  required String? placesSessionToken,
  LatLng? mapCenter,
}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return [];

  final shouldSearchTitles = trimmedQuery.length >= 2;

  final results = await Future.wait([
    geocoding.placesAutocomplete(
      input: trimmedQuery,
      sessionToken: placesSessionToken,
      biasLat: mapCenter?.latitude,
      biasLng: mapCenter?.longitude,
      radiusMeters: 50000,
    ),
    shouldSearchTitles && config.includesSpots
        ? spotService.searchSpotsByTitle(query: trimmedQuery, limit: 6)
        : Future.value(<Spot>[]),
    shouldSearchTitles && config.includesEvents
        ? eventsService.searchEventsByTitle(query: trimmedQuery, limit: 6)
        : Future.value(<Map<String, dynamic>>[]),
  ]);

  final locationSuggestions = results[0] as List<Map<String, dynamic>>;
  final matchingSpots = results[1] as List<Spot>;
  final matchingEvents = results[2] as List<Map<String, dynamic>>;

  final combinedOptions = <Map<String, dynamic>>[
    ...locationSuggestions.map(
      (suggestion) => {...suggestion, 'optionType': 'place'},
    ),
  ];

  for (final spot in matchingSpots) {
    if (spot.id == null) continue;
    if (config.excludeSpotIds.contains(spot.id)) continue;
    combinedOptions.add({
      'optionType': 'spot',
      'description': spot.name,
      'secondary': formatSpotSuggestionLocation(spot),
      'spot': spot,
    });
  }

  for (final event in matchingEvents) {
    final eventId = event['id'] as String?;
    final title = (event['title'] as String?)?.trim() ?? '';
    if (eventId == null || eventId.isEmpty || title.isEmpty) continue;
    if (config.excludeEventIds.contains(eventId)) continue;
    final secondary = formatEventSuggestionLocation(event);
    combinedOptions.add({
      'optionType': 'event',
      'description': title,
      if (secondary.isNotEmpty) 'secondary': secondary,
      'eventId': eventId,
    });
  }

  return combinedOptions;
}
