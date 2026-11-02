import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/spot_service.dart';

void main() {
  group('SpotService.resolveSuggestionContributor', () {
    test('credits reporter when reporter id is present', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: ' reporter-uid ',
        reporterUserName: 'Reporter Name',
      );

      expect(contributor, isNotNull);
      expect(contributor!['userId'], 'reporter-uid');
      expect(contributor['userName'], 'Reporter Name');
    });

    test('uses reporter id as fallback name when reporter name missing', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: 'reporter-uid',
        reporterUserName: '   ',
      );

      expect(contributor, isNotNull);
      expect(contributor!['userId'], 'reporter-uid');
      expect(contributor['userName'], 'reporter-uid');
    });

    test('returns null when reporter id missing (never credits moderator)', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: null,
        reporterUserName: 'Guest Name',
      );

      expect(contributor, isNull);
    });

    test('returns null when reporter id is blank', () {
      final contributor = SpotService.resolveSuggestionContributor(
        reporterUserId: '   ',
        reporterUserName: 'Reporter Name',
      );

      expect(contributor, isNull);
    });
  });

  group('SpotService.anonymousSuggestionContributor', () {
    test('uses the anonymous sentinel without a display name', () {
      final contributor = SpotService.anonymousSuggestionContributor();

      expect(contributor['userId'], SpotService.anonymousContributorUserId);
      expect(contributor['userName'], '');
      expect(
        SpotService.isAnonymousContributorUserId(contributor['userId']),
        isTrue,
      );
    });

    test('treats empty user ids as anonymous', () {
      expect(SpotService.isAnonymousContributorUserId(null), isTrue);
      expect(SpotService.isAnonymousContributorUserId(''), isTrue);
      expect(SpotService.isAnonymousContributorUserId('  '), isTrue);
      expect(SpotService.isAnonymousContributorUserId('real-uid'), isFalse);
    });
  });
}
