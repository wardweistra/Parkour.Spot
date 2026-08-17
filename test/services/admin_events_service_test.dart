import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/services/admin_events_service.dart';

void main() {
  group('AdminEventsService.applyFieldDeletesForClearedEventLocation', () {
    test('deletes lat/lng/address when switching to spots', () {
      final updated = ParkourEvent(
        title: 'Jam',
        startAt: DateTime.utc(2026, 5, 28, 18),
        spotIds: const <String>['spot-1'],
      );
      final updateData = <String, dynamic>{
        'latitude': 52.37,
        'longitude': 4.89,
        'address': 'Dam Square',
        'city': 'Amsterdam',
        'countryCode': 'NL',
        'spotIds': updated.spotIds,
      };

      AdminEventsService.applyFieldDeletesForClearedEventLocation(
        updateData,
        updated,
      );

      expect(updateData['latitude'], isA<FieldValue>());
      expect(updateData['longitude'], isA<FieldValue>());
      expect(updateData['address'], isA<FieldValue>());
    });

    test('deletes lat/lng when switching to a list', () {
      final updated = ParkourEvent(
        title: 'Jam',
        startAt: DateTime.utc(2026, 5, 28, 18),
        spotListIds: const <String>['list-1'],
      );
      final updateData = <String, dynamic>{
        'latitude': 52.37,
        'longitude': 4.89,
      };

      AdminEventsService.applyFieldDeletesForClearedEventLocation(
        updateData,
        updated,
      );

      expect(updateData['latitude'], isA<FieldValue>());
      expect(updateData['longitude'], isA<FieldValue>());
    });

    test('keeps coordinates when the pin type is still set', () {
      final updated = ParkourEvent(
        title: 'Jam',
        startAt: DateTime.utc(2026, 5, 28, 18),
        latitude: 52.37,
        longitude: 4.89,
        address: 'Dam Square',
      );
      final updateData = <String, dynamic>{
        'latitude': 52.37,
        'longitude': 4.89,
        'address': 'Dam Square',
      };

      AdminEventsService.applyFieldDeletesForClearedEventLocation(
        updateData,
        updated,
      );

      expect(updateData['latitude'], 52.37);
      expect(updateData['longitude'], 4.89);
      expect(updateData['address'], 'Dam Square');
    });
  });
}
