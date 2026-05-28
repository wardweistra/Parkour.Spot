import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_suggestion_utils.dart';

void main() {
  group('eventSuggestionBlockedReasonKey', () {
    test('allows external events when not duplicate and id is present', () {
      final event = ParkourEvent(
        id: 'event-1',
        title: 'External Jam',
        startAt: DateTime.utc(2026, 6, 1),
        eventSourceId: 'ics-source',
        eventSourceName: 'External Calendar',
      );

      expect(eventSuggestionBlockedReasonKey(event), isNull);
    });

    test('blocks duplicate events', () {
      final event = ParkourEvent(
        id: 'event-1',
        title: 'Duplicate Jam',
        startAt: DateTime.utc(2026, 6, 1),
        duplicateOf: 'native-event-1',
      );

      expect(
        eventSuggestionBlockedReasonKey(event),
        'eventDetailCannotSuggestForDuplicate',
      );
    });

    test('blocks events without id', () {
      final event = ParkourEvent(
        title: 'No id',
        startAt: DateTime.utc(2026, 6, 1),
      );

      expect(
        eventSuggestionBlockedReasonKey(event),
        'eventDetailUnableSuggestNow',
      );
    });
  });

  group('isNativeEventData', () {
    test('returns true when eventSourceId is missing or empty', () {
      expect(isNativeEventData(<String, dynamic>{}), isTrue);
      expect(isNativeEventData(<String, dynamic>{'eventSourceId': null}), isTrue);
      expect(isNativeEventData(<String, dynamic>{'eventSourceId': ''}), isTrue);
      expect(isNativeEventData(<String, dynamic>{'eventSourceId': '   '}), isTrue);
    });

    test('returns false when eventSourceId is set', () {
      expect(
        isNativeEventData(<String, dynamic>{'eventSourceId': 'ics-source'}),
        isFalse,
      );
    });
  });
}
