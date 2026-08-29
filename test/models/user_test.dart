import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/user.dart';

void main() {
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
