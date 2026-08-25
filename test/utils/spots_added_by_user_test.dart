import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/utils/spots_added_by_user.dart';

Spot buildSpot({
  required String name,
  String? createdBy,
  DateTime? createdAt,
  bool createdFromCreateNative = false,
}) {
  return Spot(
    name: name,
    description: 'Description',
    latitude: 48.6,
    longitude: 2.4,
    createdBy: createdBy,
    createdAt: createdAt,
    createdFromCreateNative: createdFromCreateNative,
  );
}

void main() {
  group('isSpotAddedByUser', () {
    test('matches the creating user', () {
      final spot = buildSpot(name: 'Rail', createdBy: 'user-1');
      expect(isSpotAddedByUser(spot, 'user-1'), isTrue);
    });

    test('rejects spots created by someone else', () {
      final spot = buildSpot(name: 'Rail', createdBy: 'user-2');
      expect(isSpotAddedByUser(spot, 'user-1'), isFalse);
    });

    test('rejects missing creator or empty user id', () {
      expect(isSpotAddedByUser(buildSpot(name: 'Rail'), 'user-1'), isFalse);
      expect(
        isSpotAddedByUser(buildSpot(name: 'Rail', createdBy: 'user-1'), ''),
        isFalse,
      );
      expect(
        isSpotAddedByUser(buildSpot(name: 'Rail', createdBy: '  '), '  '),
        isFalse,
      );
    });

    test('rejects spots created via Create native', () {
      final spot = buildSpot(
        name: 'Copied rail',
        createdBy: 'user-1',
        createdFromCreateNative: true,
      );
      expect(isSpotAddedByUser(spot, 'user-1'), isFalse);
    });
  });

  group('sortSpotsAddedByUser', () {
    test('orders newest first then by name', () {
      final older = buildSpot(
        name: 'Alpha',
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final newer = buildSpot(
        name: 'Zulu',
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026, 8, 1),
      );
      final sameDayA = buildSpot(
        name: 'Beta',
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026, 4, 1),
      );
      final sameDayB = buildSpot(
        name: 'alpha',
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026, 4, 1),
      );

      final sorted = sortSpotsAddedByUser([older, sameDayB, newer, sameDayA]);

      expect(sorted.map((spot) => spot.name).toList(), [
        'Zulu',
        'alpha',
        'Beta',
        'Alpha',
      ]);
    });
  });

  group('spotTrackingListRoutePath', () {
    test('keeps owner tracking lists on private profile routes', () {
      expect(
        spotTrackingListRoutePath(SpotTrackingListType.wantToVisit),
        '/profile/want-to-visit',
      );
      expect(
        spotTrackingListRoutePath(SpotTrackingListType.visited),
        '/profile/visited',
      );
      expect(
        spotTrackingListRoutePath(SpotTrackingListType.added),
        '/profile/added',
      );
    });
  });

  group('added-by-you public list', () {
    test('builds a public synthetic list as the first profile entry', () {
      final list = buildAddedByUserSpotList(
        userId: 'user-1',
        name: 'Added by you',
        spotCount: 4,
      );

      expect(list.id, 'added-by:user-1');
      expect(isAddedByUserListId(list.id), isTrue);
      expect(list.visibility, SpotListVisibility.public);
      expect(list.spotCount, 4);
      expect(list.createdBy, 'user-1');
      expect(addedByUserPublicListPath('hank'), '/user/hank/added');
      expect(isAddedByUserListId('list-1'), isFalse);
    });
  });
}
