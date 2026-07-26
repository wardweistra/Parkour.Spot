import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/parkour_event.dart';
import 'package:parkour_spot/utils/event_duplicate_merge.dart';

ParkourEvent _event({
  String title = 'Original',
  String? description,
  List<String> imageUrls = const [],
  String? websiteUrl,
  DateTime? startAt,
  DateTime? endAt,
  bool isDateOnly = false,
  String? timeZone,
  String? timeZoneSource,
  double? latitude,
  double? longitude,
  String? address,
  String? city,
  String? countryCode,
  List<String> spotIds = const [],
  List<String> spotListIds = const [],
}) {
  return ParkourEvent(
    title: title,
    description: description,
    imageUrls: imageUrls,
    websiteUrl: websiteUrl,
    startAt: startAt ?? DateTime.utc(2026, 7, 1, 10),
    endAt: endAt,
    isDateOnly: isDateOnly,
    timeZone: timeZone,
    timeZoneSource: timeZoneSource,
    latitude: latitude,
    longitude: longitude,
    address: address,
    city: city,
    countryCode: countryCode,
    spotIds: spotIds,
    spotListIds: spotListIds,
  );
}

void main() {
  group('buildEventDuplicateMergeUpdates', () {
    test('returns empty map when no flags set', () {
      final original = _event(title: 'A');
      final duplicate = _event(
        title: 'B',
        description: 'Desc',
        imageUrls: ['https://example.com/a.jpg'],
      );

      expect(
        buildEventDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
        ),
        isEmpty,
      );
    });

    test('appends unique photos only', () {
      final original = _event(imageUrls: ['https://example.com/a.jpg']);
      final duplicate = _event(
        imageUrls: [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
      );

      final updates = buildEventDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        transferPhotos: true,
      );

      expect(updates['imageUrls'], [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    test('does not update photos when all already present', () {
      final original = _event(imageUrls: ['https://example.com/a.jpg']);
      final duplicate = _event(imageUrls: ['https://example.com/a.jpg']);

      expect(
        buildEventDuplicateMergeUpdates(
          original: original,
          duplicate: duplicate,
          transferPhotos: true,
        ),
        isEmpty,
      );
    });

    test('unions linked spots and spot lists', () {
      final original = _event(spotIds: ['s1'], spotListIds: ['l1']);
      final duplicate = _event(
        spotIds: ['s1', 's2'],
        spotListIds: ['l2'],
      );

      final updates = buildEventDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        transferLinkedSpots: true,
      );

      expect(updates['spotIds'], ['s1', 's2']);
      expect(updates['spotListIds'], ['l1', 'l2']);
    });

    test('overwrites title description location schedule website when flagged',
        () {
      final original = _event(
        title: 'Original',
        description: 'Old',
        websiteUrl: 'https://old.example',
        latitude: 1,
        longitude: 2,
        address: 'Old St',
        startAt: DateTime.utc(2026, 1, 1),
      );
      final duplicate = _event(
        title: 'Duplicate Title',
        description: 'New desc',
        websiteUrl: 'https://new.example',
        latitude: 50.1,
        longitude: 4.2,
        address: 'New St',
        city: 'Brussels',
        countryCode: 'BE',
        startAt: DateTime.utc(2026, 8, 15, 9),
        endAt: DateTime.utc(2026, 8, 15, 17),
        isDateOnly: true,
        timeZone: 'Europe/Brussels',
        timeZoneSource: 'feed',
      );

      final updates = buildEventDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteTitle: true,
        overwriteDescription: true,
        overwriteLocation: true,
        overwriteSchedule: true,
        overwriteWebsite: true,
      );

      expect(updates['title'], 'Duplicate Title');
      expect(updates['description'], 'New desc');
      expect(updates['websiteUrl'], 'https://new.example');
      expect(updates['latitude'], 50.1);
      expect(updates['longitude'], 4.2);
      expect(updates['address'], 'New St');
      expect(updates['city'], 'Brussels');
      expect(updates['countryCode'], 'BE');
      expect(updates['startAt'], Timestamp.fromDate(DateTime.utc(2026, 8, 15, 9)));
      expect(updates['endAt'], Timestamp.fromDate(DateTime.utc(2026, 8, 15, 17)));
      expect(updates['isDateOnly'], isTrue);
      expect(updates['timeZone'], 'Europe/Brussels');
      expect(updates['timeZoneSource'], 'feed');
    });

    test('skips overwrite fields when duplicate lacks values', () {
      final original = _event(title: 'Original', description: 'Keep');
      final duplicate = _event(title: '  ', description: null, websiteUrl: '');

      final updates = buildEventDuplicateMergeUpdates(
        original: original,
        duplicate: duplicate,
        overwriteTitle: true,
        overwriteDescription: true,
        overwriteWebsite: true,
      );

      expect(updates, isEmpty);
    });
  });

  group('eventHas* helpers', () {
    test('detect transferable and overwriteable fields', () {
      final empty = _event(title: 'T');
      expect(eventHasTransferablePhotos(empty), isFalse);
      expect(eventHasTransferableLinkedSpots(empty), isFalse);
      expect(eventHasOverwriteDescription(empty), isFalse);
      expect(eventHasOverwriteLocation(empty), isFalse);
      expect(eventHasOverwriteWebsite(empty), isFalse);
      expect(eventHasOverwriteTitle(empty), isTrue);
      expect(eventHasOverwriteSchedule(empty), isTrue);

      final full = _event(
        title: 'T',
        description: 'D',
        imageUrls: ['https://example.com/x.jpg'],
        websiteUrl: 'https://example.com',
        latitude: 1,
        longitude: 2,
        spotIds: ['s1'],
      );
      expect(eventHasTransferablePhotos(full), isTrue);
      expect(eventHasTransferableLinkedSpots(full), isTrue);
      expect(eventHasOverwriteDescription(full), isTrue);
      expect(eventHasOverwriteLocation(full), isTrue);
      expect(eventHasOverwriteWebsite(full), isTrue);
    });
  });
}
