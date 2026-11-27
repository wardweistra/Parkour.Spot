import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/user.dart';

void main() {
  group('User.emailNewsletter', () {
    test('defaults to on when never chosen', () {
      expect(User.fromMap({'id': 'u1'}).emailNewsletter, isTrue);
      expect(
        User.fromMap({'id': 'u1', 'emailPrefs': <String, dynamic>{}})
            .emailNewsletter,
        isTrue,
      );
    });

    test('reads an opt-out from emailPrefs.newsletter', () {
      final user = User.fromMap({
        'id': 'u1',
        'emailPrefs': {'newsletter': false},
      });
      expect(user.emailNewsletter, isFalse);
      expect(user.copyWith(emailNewsletter: true).emailNewsletter, isTrue);
    });

    test('is not written back by toMap', () {
      final user = User.fromMap({
        'id': 'u1',
        'emailPrefs': {'newsletter': false},
      });
      expect(user.toMap().containsKey('emailPrefs'), isFalse);
      expect(user.toMap().containsKey('emailNewsletter'), isFalse);
    });
  });
}
