import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../models/parkour_event.dart';
import '../models/spot.dart';
import '../services/admin_events_service.dart';
import '../services/geocoding_service.dart';
import '../services/spot_service.dart';
import '../utils/event_date_window.dart';
import '../widgets/explore_entity_picker/explore_entity_picker_config.dart';

typedef ExplorePlacesFetcher =
    Future<List<Map<String, dynamic>>> Function({
      required String query,
      String? sessionToken,
      LatLng? mapCenter,
    });

typedef ExploreSpotsFetcher =
    Future<List<Spot>> Function({required String query});

typedef ExploreEventsFetcher =
    Future<List<Map<String, dynamic>>> Function({required String query});

const Duration kExploreAutocompleteDebounce = Duration(milliseconds: 150);

DateTime? parseEventSearchStartAt(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}

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

String formatEventCandidateSubtitle(ParkourEvent event) {
  final parts = <String>[];
  parts.add(DateFormat.yMMMd().add_jm().format(event.startAt.toLocal()));
  final location = formatEventSuggestionLocation({
    'city': event.city,
    'countryCode': event.countryCode,
  });
  if (location.isNotEmpty) {
    parts.add(location);
  }
  return parts.join(' · ');
}

/// Event title autocomplete for moderator tools (no place/spot suggestions).
Future<List<Map<String, dynamic>>> buildEventTitleAutocompleteOptions({
  required String query,
  required AdminEventsService eventsService,
  Set<String> excludeEventIds = const {},
  EventDateWindow? dateWindow,
  int limit = 8,
}) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.length < 2) return [];

  final matches = await eventsService.searchEventsByTitle(
    query: trimmedQuery,
    limit: limit * 3,
  );

  final options = <Map<String, dynamic>>[];
  for (final event in matches) {
    final eventId = event['id'] as String?;
    final title = (event['title'] as String?)?.trim() ?? '';
    if (eventId == null || eventId.isEmpty || title.isEmpty) continue;
    if (excludeEventIds.contains(eventId)) continue;

    final startAt = parseEventSearchStartAt(event['startAt']);
    if (dateWindow != null) {
      if (startAt == null || !dateWindow.overlaps(startAt, startAt)) {
        continue;
      }
    }

    final location = formatEventSuggestionLocation(event);
    final secondaryParts = <String>[];
    if (startAt != null) {
      secondaryParts.add(DateFormat.yMMMd().add_jm().format(startAt.toLocal()));
    }
    if (location.isNotEmpty) {
      secondaryParts.add(location);
    }

    options.add({
      'optionType': 'event',
      'description': title,
      if (secondaryParts.isNotEmpty) 'secondary': secondaryParts.join(' · '),
      'eventId': eventId,
    });
    if (options.length >= limit) break;
  }

  return options;
}

double zoomLevelForPlaceDetails(Map<String, dynamic> details) {
  final types = details['types'] as List<dynamic>? ?? [];

  if (types.contains('country')) return 6.0;
  if (types.contains('administrative_area_level_1')) return 8.0;
  if (types.contains('administrative_area_level_2')) return 10.0;
  if (types.contains('locality') ||
      types.contains('administrative_area_level_3')) {
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

List<Map<String, dynamic>> mapPlaceSuggestions(
  List<Map<String, dynamic>> suggestions,
) {
  return [
    for (final suggestion in suggestions)
      {...suggestion, 'optionType': 'place'},
  ];
}

List<Map<String, dynamic>> mapSpotSuggestions(
  List<Spot> spots, {
  Set<String> excludeSpotIds = const {},
}) {
  final options = <Map<String, dynamic>>[];
  for (final spot in spots) {
    if (spot.id == null) continue;
    if (excludeSpotIds.contains(spot.id)) continue;
    options.add({
      'optionType': 'spot',
      'description': spot.name,
      'secondary': formatSpotSuggestionLocation(spot),
      'spot': spot,
    });
  }
  return options;
}

List<Map<String, dynamic>> mapEventSuggestions(
  List<Map<String, dynamic>> events, {
  Set<String> excludeEventIds = const {},
}) {
  final options = <Map<String, dynamic>>[];
  for (final event in events) {
    final eventId = event['id'] as String?;
    final title = (event['title'] as String?)?.trim() ?? '';
    if (eventId == null || eventId.isEmpty || title.isEmpty) continue;
    if (excludeEventIds.contains(eventId)) continue;
    final secondary = formatEventSuggestionLocation(event);
    options.add({
      'optionType': 'event',
      'description': title,
      if (secondary.isNotEmpty) 'secondary': secondary,
      'eventId': eventId,
    });
  }
  return options;
}

/// Progressive Explore autocomplete: paints each source as it returns.
class ExploreAutocompleteSession extends ChangeNotifier {
  ExploreAutocompleteSession({
    required this.config,
    required this.fetchPlaces,
    required this.fetchSpots,
    required this.fetchEvents,
    this.mapCenterProvider,
    this.placesSessionTokenProvider,
    this.debounce = kExploreAutocompleteDebounce,
  });

  final ExploreEntityPickerConfig config;
  final ExplorePlacesFetcher fetchPlaces;
  final ExploreSpotsFetcher fetchSpots;
  final ExploreEventsFetcher fetchEvents;
  final LatLng? Function()? mapCenterProvider;
  final String? Function()? placesSessionTokenProvider;
  final Duration debounce;

  Timer? _debounceTimer;
  int _generation = 0;
  String _query = '';
  bool _isLoading = false;
  int _highlightIndex = 0;

  List<Map<String, dynamic>> _places = const [];
  List<Map<String, dynamic>> _spots = const [];
  List<Map<String, dynamic>> _events = const [];
  bool _placesDone = true;
  bool _spotsDone = true;
  bool _eventsDone = true;

  String get query => _query;
  bool get isLoading => _isLoading;
  int get highlightIndex => _highlightIndex;

  List<Map<String, dynamic>> get options => [..._places, ..._spots, ..._events];

  bool get showOverlay =>
      _query.isNotEmpty && (_isLoading || options.isNotEmpty);

  Map<String, dynamic>? get highlightedOption {
    final current = options;
    if (current.isEmpty) return null;
    final index = _highlightIndex.clamp(0, current.length - 1);
    return current[index];
  }

  void onQueryChanged(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }

    _query = trimmed;
    _isLoading = true;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _startFetch(trimmed));
  }

  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _generation++;
    _query = '';
    _places = const [];
    _spots = const [];
    _events = const [];
    _placesDone = true;
    _spotsDone = true;
    _eventsDone = true;
    _isLoading = false;
    _highlightIndex = 0;
    notifyListeners();
  }

  void highlightNext() {
    final current = options;
    if (current.isEmpty) return;
    final next = (_highlightIndex + 1).clamp(0, current.length - 1);
    if (next == _highlightIndex) return;
    _highlightIndex = next;
    notifyListeners();
  }

  void highlightPrevious() {
    final current = options;
    if (current.isEmpty) return;
    final next = (_highlightIndex - 1).clamp(0, current.length - 1);
    if (next == _highlightIndex) return;
    _highlightIndex = next;
    notifyListeners();
  }

  void _startFetch(String query) {
    final gen = ++_generation;
    final shouldSearchTitles = query.length >= 2;
    _places = const [];
    _spots = const [];
    _events = const [];
    _placesDone = false;
    _spotsDone = !(shouldSearchTitles && config.includesSpots);
    _eventsDone = !(shouldSearchTitles && config.includesEvents);
    _isLoading = true;
    _highlightIndex = 0;
    notifyListeners();

    final center = mapCenterProvider?.call();
    final token = placesSessionTokenProvider?.call();

    unawaited(_fetchPlaces(gen, query, token, center));
    if (!_spotsDone) {
      unawaited(_fetchSpots(gen, query));
    }
    if (!_eventsDone) {
      unawaited(_fetchEvents(gen, query));
    }
  }

  Future<void> _fetchPlaces(
    int gen,
    String query,
    String? token,
    LatLng? center,
  ) async {
    try {
      final list = await fetchPlaces(
        query: query,
        sessionToken: token,
        mapCenter: center,
      );
      if (gen != _generation) return;
      _places = mapPlaceSuggestions(list);
    } catch (_) {
      if (gen != _generation) return;
      _places = const [];
    } finally {
      if (gen == _generation) {
        _placesDone = true;
        _finishSource();
      }
    }
  }

  Future<void> _fetchSpots(int gen, String query) async {
    try {
      final list = await fetchSpots(query: query);
      if (gen != _generation) return;
      _spots = mapSpotSuggestions(list, excludeSpotIds: config.excludeSpotIds);
    } catch (_) {
      if (gen != _generation) return;
      _spots = const [];
    } finally {
      if (gen == _generation) {
        _spotsDone = true;
        _finishSource();
      }
    }
  }

  Future<void> _fetchEvents(int gen, String query) async {
    try {
      final list = await fetchEvents(query: query);
      if (gen != _generation) return;
      _events = mapEventSuggestions(
        list,
        excludeEventIds: config.excludeEventIds,
      );
    } catch (_) {
      if (gen != _generation) return;
      _events = const [];
    } finally {
      if (gen == _generation) {
        _eventsDone = true;
        _finishSource();
      }
    }
  }

  void _finishSource() {
    _isLoading = !(_placesDone && _spotsDone && _eventsDone);
    _clampHighlight();
    notifyListeners();
  }

  void _clampHighlight() {
    final current = options;
    if (current.isEmpty) {
      _highlightIndex = 0;
      return;
    }
    if (_highlightIndex >= current.length) {
      _highlightIndex = current.length - 1;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _generation++;
    super.dispose();
  }
}

Future<void> warmupExploreAutocomplete({
  required GeocodingService geocoding,
  required SpotService spotService,
  required AdminEventsService eventsService,
}) {
  return Future.wait([
    geocoding.warmupPlacesAutocomplete(),
    spotService.warmupSearchSpotsByTitle(),
    eventsService.warmupSearchEventsByTitle(),
  ]);
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

  return [
    ...mapPlaceSuggestions(results[0] as List<Map<String, dynamic>>),
    ...mapSpotSuggestions(
      results[1] as List<Spot>,
      excludeSpotIds: config.excludeSpotIds,
    ),
    ...mapEventSuggestions(
      results[2] as List<Map<String, dynamic>>,
      excludeEventIds: config.excludeEventIds,
    ),
  ];
}
