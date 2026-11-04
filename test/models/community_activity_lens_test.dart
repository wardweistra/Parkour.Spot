import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/community_activity.dart';
import 'package:parkour_spot/models/community_activity_lens.dart';
import 'package:parkour_spot/models/event_map_pin.dart';

CommunityActivityItem _item(String id, CommunityActivityKind kind) {
  return CommunityActivityItem(
    id: id,
    kind: kind,
    latitude: 52.37,
    longitude: 4.9,
    occurredAt: DateTime.utc(2026, 11, 1, 10),
    spotId: 'spot-$id',
  );
}

CommunityEventItem _event(String id, {bool isPast = false}) {
  return CommunityEventItem(
    pin: EventMapPin(
      id: 'pin-$id',
      eventId: id,
      kind: EventMapPinKind.venue,
      latitude: 52.37,
      longitude: 4.9,
      title: 'Jam $id',
      startAt: DateTime.utc(2026, 11, 2, 10),
    ),
    isPast: isPast,
  );
}

CommunityActivityFeed _mixedFeed() {
  return CommunityActivityFeed(
    past: [
      _item('added', CommunityActivityKind.spotAdded),
      _item('photo', CommunityActivityKind.spotPhotoAdded),
      _item('rated', CommunityActivityKind.spotRated),
      _item('checkin', CommunityActivityKind.spotCheckIn),
    ],
    pastEvents: [_event('past-e', isPast: true)],
    upcoming: [_item('plan', CommunityActivityKind.spotTrainingPlan)],
    events: [_event('up-e')],
    totalCount: 10,
    pastTotal: 8,
    upcomingPlanTotal: 1,
    eventTotal: 1,
    hasMorePast: true,
    hasMoreUpcoming: true,
  );
}

void main() {
  group('CommunityActivityLensQuery', () {
    test('maps lenses to Firestore kinds and event inclusion', () {
      expect(CommunityActivityLens.all.firestoreKinds, isNull);
      expect(CommunityActivityLens.all.includeUpcomingEvents, isTrue);

      expect(CommunityActivityLens.events.firestoreKinds, ['event_ended']);
      expect(CommunityActivityLens.events.includeUpcomingEvents, isTrue);

      expect(CommunityActivityLens.sessions.firestoreKinds, [
        'spot_check_in',
        'spot_training_plan',
      ]);
      expect(CommunityActivityLens.sessions.includeUpcomingEvents, isFalse);

      expect(CommunityActivityLens.contributions.firestoreKinds, [
        'spot_added',
        'spot_photo_added',
        'spot_rated',
      ]);
      expect(
        CommunityActivityLens.contributions.includeUpcomingEvents,
        isFalse,
      );
    });
  });

  group('filterCommunityActivityFeed', () {
    test('all returns the same feed instance', () {
      final feed = _mixedFeed();
      expect(
        identical(filterCommunityActivityFeed(feed, CommunityActivityLens.all), feed),
        isTrue,
      );
    });

    test('events keeps only past and upcoming events', () {
      final filtered = filterCommunityActivityFeed(
        _mixedFeed(),
        CommunityActivityLens.events,
      );
      expect(filtered.past, isEmpty);
      expect(filtered.upcoming, isEmpty);
      expect(filtered.pastEvents, hasLength(1));
      expect(filtered.events, hasLength(1));
      expect(filtered.hasMorePast, isTrue);
      expect(filtered.hasMoreUpcoming, isTrue);
      expect(filtered.totalCount, 10);
    });

    test('sessions keeps check-ins and training plans', () {
      final filtered = filterCommunityActivityFeed(
        _mixedFeed(),
        CommunityActivityLens.sessions,
      );
      expect(
        filtered.past.map((e) => e.kind),
        [CommunityActivityKind.spotCheckIn],
      );
      expect(
        filtered.upcoming.map((e) => e.kind),
        [CommunityActivityKind.spotTrainingPlan],
      );
      expect(filtered.pastEvents, isEmpty);
      expect(filtered.events, isEmpty);
    });

    test('contributions keeps new spots, photos, and ratings', () {
      final filtered = filterCommunityActivityFeed(
        _mixedFeed(),
        CommunityActivityLens.contributions,
      );
      expect(
        filtered.past.map((e) => e.kind).toList(),
        [
          CommunityActivityKind.spotAdded,
          CommunityActivityKind.spotPhotoAdded,
          CommunityActivityKind.spotRated,
        ],
      );
      expect(filtered.upcoming, isEmpty);
      expect(filtered.pastEvents, isEmpty);
      expect(filtered.events, isEmpty);
    });

    test('lens with no matches yields empty itemCount but keeps paging flags', () {
      final feed = CommunityActivityFeed(
        past: [_item('checkin', CommunityActivityKind.spotCheckIn)],
        hasMorePast: true,
        pastTotal: 5,
      );
      final filtered = filterCommunityActivityFeed(
        feed,
        CommunityActivityLens.events,
      );
      expect(filtered.isEmpty, isTrue);
      expect(filtered.hasMorePast, isTrue);
      expect(filtered.pastTotal, 5);
    });
  });

  group('communityActivityKindMatchesLens', () {
    test('sessions and contributions map expected kinds', () {
      expect(
        communityActivityKindMatchesLens(
          CommunityActivityKind.spotCheckIn,
          CommunityActivityLens.sessions,
        ),
        isTrue,
      );
      expect(
        communityActivityKindMatchesLens(
          CommunityActivityKind.spotAdded,
          CommunityActivityLens.sessions,
        ),
        isFalse,
      );
      expect(
        communityActivityKindMatchesLens(
          CommunityActivityKind.spotPhotoAdded,
          CommunityActivityLens.contributions,
        ),
        isTrue,
      );
      expect(
        communityActivityKindMatchesLens(
          CommunityActivityKind.spotRated,
          CommunityActivityLens.contributions,
        ),
        isTrue,
      );
      expect(
        communityActivityKindMatchesLens(
          CommunityActivityKind.spotCheckIn,
          CommunityActivityLens.events,
        ),
        isFalse,
      );
    });
  });
}
