import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/widgets/event_duplicate_picker.dart';

void main() {
  group('isValidNativeDuplicateOriginal', () {
    ParkourEvent event({
      String? eventSourceId,
      String? duplicateOf,
    }) {
      return ParkourEvent(
        id: 'event-1',
        title: 'Jam',
        startAt: DateTime.utc(2026, 5, 28, 18),
        eventSourceId: eventSourceId,
        duplicateOf: duplicateOf,
      );
    }

    test('accepts native events without duplicate link', () {
      expect(isValidNativeDuplicateOriginal(event()), isTrue);
    });

    test('rejects external events', () {
      expect(
        isValidNativeDuplicateOriginal(event(eventSourceId: 'ics-source')),
        isFalse,
      );
    });

    test('rejects events already marked duplicate', () {
      expect(
        isValidNativeDuplicateOriginal(event(duplicateOf: 'other-event')),
        isFalse,
      );
    });
  });

  group('canConfirmEventDuplicateSelection', () {
    ParkourEvent event({
      String? id,
      String? eventSourceId,
      String? duplicateOf,
    }) {
      return ParkourEvent(
        id: id ?? 'event-1',
        title: 'Jam',
        startAt: DateTime.utc(2026, 5, 28, 18),
        eventSourceId: eventSourceId,
        duplicateOf: duplicateOf,
      );
    }

    test('user report allows external and duplicate events', () {
      expect(
        canConfirmEventDuplicateSelection(
          event: event(eventSourceId: 'ics', duplicateOf: 'other'),
          currentEventId: 'current',
          mode: EventDuplicatePickerMode.userReport,
        ),
        isTrue,
      );
    });

    test('user report rejects selecting the current event', () {
      expect(
        canConfirmEventDuplicateSelection(
          event: event(id: 'current'),
          currentEventId: 'current',
          mode: EventDuplicatePickerMode.userReport,
        ),
        isFalse,
      );
    });

    test('moderator mark only allows native non-duplicate events', () {
      expect(
        canConfirmEventDuplicateSelection(
          event: event(),
          currentEventId: 'current',
          mode: EventDuplicatePickerMode.moderatorMark,
        ),
        isTrue,
      );
      expect(
        canConfirmEventDuplicateSelection(
          event: event(eventSourceId: 'ics'),
          currentEventId: 'current',
          mode: EventDuplicatePickerMode.moderatorMark,
        ),
        isFalse,
      );
      expect(
        canConfirmEventDuplicateSelection(
          event: event(duplicateOf: 'other'),
          currentEventId: 'current',
          mode: EventDuplicatePickerMode.moderatorMark,
        ),
        isFalse,
      );
    });
  });
}
