import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/app_link_paths.dart';

void main() {
  group('isNonAppLinkPath', () {
    test('flags Firebase reserved and Cloud Function paths', () {
      expect(isNonAppLinkPath('/__/auth/action'), isTrue);
      expect(isNonAppLinkPath('/__/auth/handler'), isTrue);
      expect(isNonAppLinkPath('/api/v1/spots'), isTrue);
      expect(isNonAppLinkPath('/calendar/abc123.ics'), isTrue);
      expect(isNonAppLinkPath('/mcp'), isTrue);
      expect(isNonAppLinkPath('/sitemap.xml'), isTrue);
      expect(isNonAppLinkPath('/sitemaps/spots-1.xml'), isTrue);
      expect(isNonAppLinkPath('/.well-known/assetlinks.json'), isTrue);
      expect(isNonAppLinkPath('/API/v1/spots'), isTrue);
    });

    test('leaves app routes alone', () {
      expect(isNonAppLinkPath('/'), isFalse);
      expect(isNonAppLinkPath('/explore'), isFalse);
      expect(isNonAppLinkPath('/spot/abc'), isFalse);
      expect(isNonAppLinkPath('/event/abc'), isFalse);
      expect(isNonAppLinkPath('/user/someone'), isFalse);
      expect(isNonAppLinkPath('/list/abc'), isFalse);
      expect(isNonAppLinkPath('/nl'), isFalse);
      expect(isNonAppLinkPath('/nl/amsterdam'), isFalse);
      expect(isNonAppLinkPath('/nl/amsterdam/abc'), isFalse);
      // Country and city slugs that merely start like a reserved name.
      expect(isNonAppLinkPath('/mc'), isFalse);
      expect(isNonAppLinkPath('/apiary'), isFalse);
      expect(isNonAppLinkPath('/calendar'), isFalse);
    });
  });
}
