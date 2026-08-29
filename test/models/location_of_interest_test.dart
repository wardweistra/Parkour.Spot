import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/location_of_interest.dart';

LocationOfInterest buildLocation({
  required String id,
  LocationOfInterestKind kind = LocationOfInterestKind.saved,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return LocationOfInterest(
    id: id,
    userId: 'user-1',
    latitude: 50.8,
    longitude: 4.3,
    kind: kind,
    enabled: true,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('LocationOfInterest.compareForDisplay', () {
    test('keeps last-known first even when it is older', () {
      final lastKnown = buildLocation(
        id: 'lastKnown',
        kind: LocationOfInterestKind.lastKnown,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final saved = buildLocation(
        id: 'home',
        createdAt: DateTime.utc(2026, 8, 1),
      );

      final items = [saved, lastKnown]
        ..sort(LocationOfInterest.compareForDisplay);

      expect(items.map((loc) => loc.id), ['lastKnown', 'home']);
    });

    test('orders saved locations by created time, not updated time', () {
      final older = buildLocation(
        id: 'older',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 8, 29),
      );
      final newer = buildLocation(
        id: 'newer',
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 2),
      );

      final items = [older, newer]..sort(LocationOfInterest.compareForDisplay);

      expect(items.map((loc) => loc.id), ['newer', 'older']);
    });

    test('does not reshuffle when only updatedAt changes', () {
      final home = buildLocation(
        id: 'home',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final work = buildLocation(
        id: 'work',
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      );

      final before = [home, work]..sort(LocationOfInterest.compareForDisplay);
      final afterBellToggle = [
        buildLocation(
          id: 'home',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 8, 29),
        ),
        work,
      ]..sort(LocationOfInterest.compareForDisplay);

      expect(before.map((loc) => loc.id), ['work', 'home']);
      expect(afterBellToggle.map((loc) => loc.id), ['work', 'home']);
    });
  });
}
