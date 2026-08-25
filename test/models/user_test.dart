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
}
