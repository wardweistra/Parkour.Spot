import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/user.dart';

void main() {
  group('User.isRatedSpotsListPublic', () {
    test('defaults to false', () {
      final user = User(id: 'u1', email: 'a@b.c');
      expect(user.isRatedSpotsListPublic, isFalse);
      expect(user.toMap()['isRatedSpotsListPublic'], isFalse);
    });

    test('round-trips from map and copyWith', () {
      final user = User.fromMap({
        'id': 'u1',
        'email': 'a@b.c',
        'isRatedSpotsListPublic': true,
      });
      expect(user.isRatedSpotsListPublic, isTrue);
      expect(
        user.copyWith(isRatedSpotsListPublic: false).isRatedSpotsListPublic,
        isFalse,
      );
    });
  });

  group('User.isAddedSpotsListPublic', () {
    test('defaults to private when the field is missing', () {
      final user = User.fromMap({'id': 'user-1', 'email': 'user@parkour.spot'});

      expect(user.isAddedSpotsListPublic, isFalse);
      expect(user.toMap()['isAddedSpotsListPublic'], isFalse);
    });

    test('is public only when the flag is true', () {
      final user = User.fromMap({
        'id': 'user-1',
        'email': 'user@parkour.spot',
        'isAddedSpotsListPublic': true,
      });

      expect(user.isAddedSpotsListPublic, isTrue);
      expect(
        user.copyWith(isAddedSpotsListPublic: false).isAddedSpotsListPublic,
        isFalse,
      );
    });
  });

  group('User.bio', () {
    test('round-trips from map and copyWith', () {
      const bio = 'Training rails downtown on weekends.';
      final user = User.fromMap({
        'id': 'user-1',
        'email': 'user@parkour.spot',
        'bio': bio,
      });

      expect(user.bio, bio);
      expect(user.toMap()['bio'], bio);
      expect(user.copyWith(bio: null).bio, isNull);
    });

    test('is null when missing from map', () {
      final user = User.fromMap({'id': 'user-1', 'email': 'user@parkour.spot'});
      expect(user.bio, isNull);
    });
  });

  group('User.notifyEventsNearby', () {
    test('defaults to true when the field is missing', () {
      final user = User.fromMap({'id': 'user-1', 'email': 'user@parkour.spot'});

      expect(user.notifyEventsNearby, isTrue);
      expect(user.toMap()['notifyEventsNearby'], isTrue);
    });

    test('is off only when the flag is false', () {
      final user = User.fromMap({
        'id': 'user-1',
        'email': 'user@parkour.spot',
        'notifyEventsNearby': false,
      });

      expect(user.notifyEventsNearby, isFalse);
      expect(
        user.copyWith(notifyEventsNearby: true).notifyEventsNearby,
        isTrue,
      );
    });
  });
}
