import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/explore_search_autocomplete.dart';
import 'package:parkour_spot/widgets/explore_entity_picker/explore_entity_picker_config.dart';

Spot _spot(String id, String name) {
  return Spot(
    id: id,
    name: name,
    description: '',
    latitude: 0,
    longitude: 0,
    city: 'Utrecht',
    countryCode: 'nl',
  );
}

ExploreAutocompleteSession _session({
  required ExplorePlacesFetcher fetchPlaces,
  required ExploreSpotsFetcher fetchSpots,
  required ExploreEventsFetcher fetchEvents,
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return ExploreAutocompleteSession(
    config: const ExploreEntityPickerConfig(
      mode: ExploreEntityPickerMode.spotsAndEvents,
    ),
    fetchPlaces: fetchPlaces,
    fetchSpots: fetchSpots,
    fetchEvents: fetchEvents,
    debounce: debounce,
  );
}

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
      zoomLevelForPlaceDetails({
        'types': ['country'],
      }),
      6.0,
    );
    expect(
      zoomLevelForPlaceDetails({
        'types': ['locality'],
      }),
      12.0,
    );
  });

  test('debounce does not fire until the timer elapses', () {
    fakeAsync((async) {
      var placesCalls = 0;
      final session = _session(
        fetchPlaces: ({required query, sessionToken, mapCenter}) async {
          placesCalls++;
          return const [];
        },
        fetchSpots: ({required query}) async => const [],
        fetchEvents: ({required query}) async => const [],
      );

      session.onQueryChanged('u');
      async.elapse(const Duration(milliseconds: 149));
      expect(placesCalls, 0);

      session.onQueryChanged('ut');
      async.elapse(const Duration(milliseconds: 149));
      expect(placesCalls, 0);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(placesCalls, 1);

      session.dispose();
    });
  });

  test('empty query clears options and hides loading', () {
    fakeAsync((async) {
      final places = Completer<List<Map<String, dynamic>>>();
      final session = _session(
        fetchPlaces: ({required query, sessionToken, mapCenter}) =>
            places.future,
        fetchSpots: ({required query}) async => const [],
        fetchEvents: ({required query}) async => const [],
      );

      session.onQueryChanged('ut');
      expect(session.isLoading, isTrue);
      expect(session.showOverlay, isTrue);

      async.elapse(const Duration(milliseconds: 150));
      places.complete([
        {'description': 'Utrecht', 'placeId': 'p1'},
      ]);
      async.flushMicrotasks();
      expect(session.options, isNotEmpty);

      session.onQueryChanged('  ');
      expect(session.options, isEmpty);
      expect(session.isLoading, isFalse);
      expect(session.showOverlay, isFalse);

      session.dispose();
    });
  });

  test('first source to finish is visible before the others complete', () {
    fakeAsync((async) {
      final places = Completer<List<Map<String, dynamic>>>();
      final spots = Completer<List<Spot>>();
      final events = Completer<List<Map<String, dynamic>>>();
      final session = _session(
        fetchPlaces: ({required query, sessionToken, mapCenter}) =>
            places.future,
        fetchSpots: ({required query}) => spots.future,
        fetchEvents: ({required query}) => events.future,
      );

      session.onQueryChanged('ut');
      async.elapse(const Duration(milliseconds: 150));

      spots.complete([_spot('s1', 'Utrecht Gym')]);
      async.flushMicrotasks();

      expect(session.options.map((option) => option['description']), [
        'Utrecht Gym',
      ]);
      expect(session.isLoading, isTrue);
      expect(session.showOverlay, isTrue);

      places.complete([
        {'description': 'Utrecht', 'placeId': 'p1'},
      ]);
      async.flushMicrotasks();
      expect(session.options.map((option) => option['description']), [
        'Utrecht',
        'Utrecht Gym',
      ]);
      expect(session.isLoading, isTrue);

      events.complete([
        {'id': 'e1', 'title': 'Utrecht Jam', 'city': 'Utrecht'},
      ]);
      async.flushMicrotasks();
      expect(session.isLoading, isFalse);

      session.dispose();
    });
  });

  test('keeps places then spots then events as sources arrive', () {
    fakeAsync((async) {
      final places = Completer<List<Map<String, dynamic>>>();
      final spots = Completer<List<Spot>>();
      final events = Completer<List<Map<String, dynamic>>>();
      final session = _session(
        fetchPlaces: ({required query, sessionToken, mapCenter}) =>
            places.future,
        fetchSpots: ({required query}) => spots.future,
        fetchEvents: ({required query}) => events.future,
      );

      session.onQueryChanged('ut');
      async.elapse(const Duration(milliseconds: 150));

      events.complete([
        {'id': 'e1', 'title': 'Utrecht Jam'},
      ]);
      spots.complete([_spot('s1', 'Utrecht Gym')]);
      places.complete([
        {'description': 'Utrecht, Netherlands', 'placeId': 'p1'},
      ]);
      async.flushMicrotasks();

      expect(session.options.map((option) => option['optionType']), [
        'place',
        'spot',
        'event',
      ]);
      expect(session.options.map((option) => option['description']), [
        'Utrecht, Netherlands',
        'Utrecht Gym',
        'Utrecht Jam',
      ]);

      session.dispose();
    });
  });

  test('stale generation is ignored after the query changes', () {
    fakeAsync((async) {
      final firstPlaces = Completer<List<Map<String, dynamic>>>();
      final secondPlaces = Completer<List<Map<String, dynamic>>>();
      final placesQueue = [firstPlaces, secondPlaces];
      final session = _session(
        fetchPlaces: ({required query, sessionToken, mapCenter}) {
          return placesQueue.removeAt(0).future;
        },
        fetchSpots: ({required query}) async => const [],
        fetchEvents: ({required query}) async => const [],
      );

      session.onQueryChanged('ut');
      async.elapse(const Duration(milliseconds: 150));
      session.onQueryChanged('am');
      async.elapse(const Duration(milliseconds: 150));

      firstPlaces.complete([
        {'description': 'Utrecht', 'placeId': 'old'},
      ]);
      async.flushMicrotasks();
      expect(session.options.map((option) => option['description']), isEmpty);

      secondPlaces.complete([
        {'description': 'Amsterdam', 'placeId': 'new'},
      ]);
      async.flushMicrotasks();
      expect(session.options.map((option) => option['description']), [
        'Amsterdam',
      ]);

      session.dispose();
    });
  });
}
