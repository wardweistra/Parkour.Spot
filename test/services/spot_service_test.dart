import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/spot_service.dart';

void main() {
  group('SpotService.resolveSuggestionContributor', () {
    test('prefers reporter attribution when reporter id is present', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: ' reporter-uid ',
        reporterUserName: 'Reporter Name',
        approverUserId: 'moderator-uid',
        approverUserName: 'Moderator Name',
      );

      expect(contributor, isNotNull);
      expect(contributor!['userId'], 'reporter-uid');
      expect(contributor['userName'], 'Reporter Name');
    });

    test('uses reporter id as fallback name when reporter name missing', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: 'reporter-uid',
        reporterUserName: '   ',
        approverUserId: 'moderator-uid',
        approverUserName: 'Moderator Name',
      );

      expect(contributor, isNotNull);
      expect(contributor!['userId'], 'reporter-uid');
      expect(contributor['userName'], 'reporter-uid');
    });

    test('falls back to approver when reporter id missing', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: null,
        reporterUserName: null,
        approverUserId: ' moderator-uid ',
        approverUserName: 'Moderator Name',
      );

      expect(contributor, isNotNull);
      expect(contributor!['userId'], 'moderator-uid');
      expect(contributor['userName'], 'Moderator Name');
    });

    test('returns null when both reporter and approver ids missing', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: '   ',
        reporterUserName: 'Reporter Name',
        approverUserId: null,
        approverUserName: null,
      );

      expect(contributor, isNull);
    });
  });
}
