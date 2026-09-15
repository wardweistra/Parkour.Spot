import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/rating.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/spot_rating_utils.dart';

Spot spot({required String id, String? duplicateOf}) {
  return Spot(
    id: id,
    name: 'Rail',
    description: '',
    latitude: 0,
    longitude: 0,
    duplicateOf: duplicateOf,
  );
}

Rating rating({
  required String spotId,
  double value = 4,
  DateTime? updatedAt,
  DateTime? createdAt,
}) {
  return Rating(
    id: '$spotId-rating',
    spotId: spotId,
    userId: 'user-1',
    rating: value,
    updatedAt: updatedAt,
    createdAt: createdAt,
  );
}

void main() {
  group('canonicalSpotRatingSpotId', () {
    test('uses duplicateOf when set', () {
      expect(
        canonicalSpotRatingSpotId(spot(id: 'dup', duplicateOf: ' native ')),
        'native',
      );
      expect(canonicalSpotRatingSpotId(spot(id: 'native')), 'native');
    });
  });

  group('spotRatingWriteSpotId', () {
    test('uses the listing id even when duplicateOf is set', () {
      expect(
        spotRatingWriteSpotId(spot(id: 'dup', duplicateOf: 'native')),
        'dup',
      );
    });
  });

  group('spotRatingClusterIds', () {
    test('includes listing, duplicateOf, and extra ids', () {
      expect(
        spotRatingClusterIds(
          spot: spot(id: 'dup', duplicateOf: ' native '),
          extraIds: const ['sibling', ' native ', ''],
        ),
        {'dup', 'native', 'sibling'},
      );
    });
  });

  group('uniqueUserRating', () {
    test('prefers the latest updatedAt', () {
      final chosen = uniqueUserRating([
        rating(spotId: 'native', value: 5, updatedAt: DateTime.utc(2026, 1, 1)),
        rating(spotId: 'dup', value: 2, updatedAt: DateTime.utc(2026, 6, 1)),
      ]);
      expect(chosen?.spotId, 'dup');
      expect(chosen?.rating, 2);
    });

    test('falls back to createdAt when updatedAt is missing', () {
      final chosen = uniqueUserRating([
        rating(spotId: 'native', value: 1, createdAt: DateTime.utc(2026, 1, 1)),
        rating(spotId: 'dup', value: 5, createdAt: DateTime.utc(2026, 2, 1)),
      ]);
      expect(chosen?.rating, 5);
    });

    test('returns null when empty', () {
      expect(uniqueUserRating(const []), isNull);
    });
  });

  group('spotRatingSpotIdsToDelete', () {
    test('clears every cluster listing including the listing', () {
      expect(
        spotRatingSpotIdsToDelete(
          listingSpotId: 'dup',
          clusterSpotIds: const ['native', 'sibling', 'dup'],
          clearing: true,
        ),
        {'dup', 'native', 'sibling'},
      );
    });

    test('keeps the listing and deletes siblings when setting a rating', () {
      expect(
        spotRatingSpotIdsToDelete(
          listingSpotId: 'dup',
          clusterSpotIds: const ['native', 'sibling', 'dup'],
          clearing: false,
        ),
        {'native', 'sibling'},
      );
    });
  });
}
