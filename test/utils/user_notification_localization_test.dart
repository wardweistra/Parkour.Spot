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

    test('localizes nearby_training_plan with names from templateArgs', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'nearby_training_plan',
        templateArgs: const {'actorName': 'Sam', 'spotName': 'Wall'},
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Sam planned a session at Wall');
      expect(copy.body, en.notificationNearbyTrainingPlanBody);
    });

    test('localizes nearby_check_in with names from templateArgs', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'nearby_check_in',
        templateArgs: const {'actorName': 'Alex', 'spotName': 'Session'},
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Alex is training now at Session');
      expect(copy.body, en.notificationNearbyCheckInBody);
    });

    test('localizes training_plan_check_in_reminder with spot name', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'training_plan_check_in_reminder',
        templateArgs: const {'spotName': 'North Wall'},
        deeplinkKind: UserNotificationDeeplinkKind.spot,
        deeplinkId: 's1',
      );
      final copy = localizedUserNotificationCopy(n, en);
      expect(copy.title, 'Time to check in at North Wall');
      expect(copy.body, en.notificationTrainingPlanCheckInReminderBody);
    });

    test('localizes nearby_new_event with fallbacks', () {
      final n = UserNotification(
        id: '1',
        title: 'English title',
        body: 'English body',
        notificationKind: 'nearby_new_event',
        templateArgs: const {'eventName': ''},
        deeplinkKind: UserNotificationDeeplinkKind.event,
        deeplinkId: 'e1',
      );
      final copyEn = localizedUserNotificationCopy(n, en);
      expect(copyEn.title, 'New event nearby: Untitled event');
      expect(copyEn.body, en.notificationNearbyNewEventBody);

      final copyNl = localizedUserNotificationCopy(
        UserNotification(
          id: '1',
          title: 'English title',
          notificationKind: 'nearby_new_event',
          templateArgs: const {'eventName': 'Jam'},
          deeplinkKind: UserNotificationDeeplinkKind.event,
          deeplinkId: 'e1',
        ),
        nl,
      );
      expect(copyNl.title, 'Nieuw evenement in de buurt: Jam');
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
