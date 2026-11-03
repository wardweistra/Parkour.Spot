import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/community_activity.dart';

void main() {
  group('CommunityActivityFeed.fromCallableMap', () {
    test('splits event_ended past rows into pastEvents', () {
      final feed = CommunityActivityFeed.fromCallableMap({
        'past': [
          {
            'id': 'check_in_1',
            'kind': 'spot_check_in',
            'timeline': 'past',
            'latitude': 52.3,
            'longitude': 4.9,
            'occurredAt': '2026-05-10T11:00:00.000Z',
            'spotId': 'spot-1',
            'actorDisplayName': 'Kim',
          },
          {
            'id': 'event_ended_e1',
            'kind': 'event_ended',
            'timeline': 'past',
            'eventId': 'e1',
            'title': 'Friday jam',
            'pinKind': 'venue',
            'latitude': 52.37,
            'longitude': 4.89,
            'occurredAt': '2026-05-01T13:00:00.000Z',
            'startAt': '2026-05-01T10:00:00.000Z',
            'endAt': '2026-05-01T13:00:00.000Z',
            'goingCount': 4,
            'interestedCount': 2,
            'city': 'Amsterdam',
          },
        ],
        'upcoming': [],
        'events': [
          {
            'id': 'pin-upcoming',
            'eventId': 'e2',
            'kind': 'venue',
            'latitude': 52.3,
            'longitude': 4.9,
            'title': 'Next jam',
            'startAt': '2026-05-20T10:00:00.000Z',
            'goingCount': 1,
          },
        ],
      });

      expect(feed.past, hasLength(1));
      expect(feed.past.single.kind, CommunityActivityKind.spotCheckIn);
      expect(feed.pastEvents, hasLength(1));
      expect(feed.pastEvents.single.isPast, isTrue);
      expect(feed.pastEvents.single.pin.eventId, 'e1');
      expect(feed.pastEvents.single.pin.title, 'Friday jam');
      expect(feed.pastEvents.single.goingCount, 4);
      expect(feed.pastEvents.single.interestedCount, 2);
      expect(feed.events, hasLength(1));
      expect(feed.events.single.isPast, isFalse);
      expect(feed.itemCount, 3);
    });
  });
}
