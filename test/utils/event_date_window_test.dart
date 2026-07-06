import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_date_window.dart';

void main() {
  group('EventDateWindow', () {
    test('aroundEvent pads start and end by one week', () {
      final start = DateTime.utc(2026, 6, 10, 18);
      final end = DateTime.utc(2026, 6, 12, 20);
      final window = EventDateWindow.aroundEvent(startAt: start, endAt: end);

      expect(window.start, start.subtract(const Duration(days: 7)));
      expect(window.end, end.add(const Duration(days: 7)));
    });

    test('overlapsParkourEvent matches overlapping ranges', () {
      final window = EventDateWindow.aroundEvent(
        startAt: DateTime.utc(2026, 6, 10),
        endAt: DateTime.utc(2026, 6, 12),
      );

      final overlapping = ParkourEvent(
        id: 'a',
        title: 'Jam',
        startAt: DateTime.utc(2026, 6, 11),
        endAt: DateTime.utc(2026, 6, 11, 23),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final farAway = ParkourEvent(
        id: 'b',
        title: 'Later',
        startAt: DateTime.utc(2026, 8, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(window.overlapsParkourEvent(overlapping), isTrue);
      expect(window.overlapsParkourEvent(farAway), isFalse);
    });
  });
}
