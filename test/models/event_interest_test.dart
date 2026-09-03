import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/event_interest.dart';

void main() {
  group('parseEventInterestStatus', () {
    test('parses going and interested', () {
      expect(parseEventInterestStatus('going'), EventInterestStatus.going);
      expect(
        parseEventInterestStatus(' interested '),
        EventInterestStatus.interested,
      );
    });

    test('rejects unknown values', () {
      expect(parseEventInterestStatus('maybe'), isNull);
      expect(parseEventInterestStatus(null), isNull);
    });
  });

  group('EventInterest.fromMap', () {
    test('uses document ids when fields are missing', () {
      final interest = EventInterest.fromMap(
        const {'status': 'going'},
        eventId: 'event-1',
        userId: 'user-1',
      );
      expect(interest.eventId, 'event-1');
      expect(interest.userId, 'user-1');
      expect(interest.status, EventInterestStatus.going);
    });

    test('parses timestamps', () {
      final start = DateTime.utc(2026, 9, 1, 18);
      final created = DateTime.utc(2026, 8, 1, 10);
      final interest = EventInterest.fromMap(
        {
          'eventId': 'event-2',
          'userId': 'user-2',
          'status': 'interested',
          'eventStartAt': Timestamp.fromDate(start),
          'createdAt': Timestamp.fromDate(created),
        },
        eventId: 'ignored',
        userId: 'ignored',
      );
      expect(interest.eventId, 'event-2');
      expect(interest.status, EventInterestStatus.interested);
      expect(interest.eventStartAt?.toUtc(), start);
      expect(interest.createdAt?.toUtc(), created);
    });
  });

  group('EventInterestStats.fromMap', () {
    test('defaults missing counts to zero', () {
      expect(EventInterestStats.fromMap(null).goingCount, 0);
      expect(EventInterestStats.fromMap(const {}).interestedCount, 0);
    });

    test('clamps negative counts', () {
      final stats = EventInterestStats.fromMap(const {
        'goingCount': -3,
        'interestedCount': 4,
      });
      expect(stats.goingCount, 0);
      expect(stats.interestedCount, 4);
    });
  });
}
