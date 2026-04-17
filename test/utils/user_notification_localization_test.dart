import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations_en.dart';
import 'package:parkour_spot/l10n/app_localizations_nl.dart';
import 'package:parkour_spot/models/user_notification.dart';
import 'package:parkour_spot/utils/user_notification_localization.dart';

void main() {
  group('localizedUserNotificationCopy', () {
    final en = AppLocalizationsEn();
    final nl = AppLocalizationsNl();

    test('uses legacy title and body when notificationKind is absent', () {
      final n = UserNotification(
        id: '1',
        title: 'Legacy title',
        body: 'Legacy body',
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Legacy title');
      expect(copy.body, 'Legacy body');
    });

    test('localizes nearby_new_spot with fallbacks', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'nearby_new_spot',
        templateArgs: const {'actorName': '', 'spotName': ''},
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copyEn = localizedUserNotificationCopy(n, en);
      expect(copyEn.title, 'New spot nearby: Untitled spot');
      expect(
        copyEn.body,
        '${en.notificationsActorSomeone} added a new parkour spot near one of your saved locations.',
      );

      final copyNl = localizedUserNotificationCopy(n, nl);
      expect(copyNl.title, 'Nieuwe spot in de buurt: Spot zonder naam');
    });

    test('localizes nearby_check_in with names from templateArgs', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'nearby_check_in',
        templateArgs: const {
          'actorName': 'Alex',
          'spotName': 'Session',
        },
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Alex is training now at Session');
      expect(copy.body, en.notificationNearbyCheckInBody);
    });

    test('unknown notificationKind falls back to stored strings', () {
      final n = UserNotification(
        id: '1',
        title: 'Stored',
        body: 'Body',
        notificationKind: 'future_kind',
        templateArgs: const {'actorName': 'x'},
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Stored');
      expect(copy.body, 'Body');
    });
  });
}
