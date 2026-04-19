import '../l10n/app_localizations.dart';
import '../models/user_notification.dart';

/// Localized title/body for the notifications inbox.
class UserNotificationCopy {
  const UserNotificationCopy({
    required this.title,
    this.body,
  });

  final String title;
  final String? body;
}

/// Resolves [UserNotification] display strings using [AppLocalizations] when
/// [UserNotification.notificationKind] and [UserNotification.templateArgs] are set.
UserNotificationCopy localizedUserNotificationCopy(
  UserNotification notification,
  AppLocalizations l10n,
) {
  final kind = notification.notificationKind?.trim();
  final args = notification.templateArgs;

  if (kind == null || kind.isEmpty || args == null) {
    return UserNotificationCopy(
      title: notification.title,
      body: notification.body,
    );
  }

  String actorLabel(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) {
      return l10n.notificationsActorSomeone;
    }
    return t;
  }

  String spotLabel(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) {
      return l10n.notificationsSpotUntitled;
    }
    return t;
  }

  switch (kind) {
    case 'nearby_new_spot':
      return UserNotificationCopy(
        title: l10n.notificationNearbyNewSpotTitle(
          spotLabel(args['spotName']),
        ),
        body: l10n.notificationNearbyNewSpotBody(
          actorLabel(args['actorName']),
        ),
      );
    case 'nearby_check_in':
      return UserNotificationCopy(
        title: l10n.notificationNearbyCheckInTitle(
          actorLabel(args['actorName']),
          spotLabel(args['spotName']),
        ),
        body: l10n.notificationNearbyCheckInBody,
      );
    case 'nearby_training_plan':
      return UserNotificationCopy(
        title: l10n.notificationNearbyTrainingPlanTitle(
          actorLabel(args['actorName']),
          spotLabel(args['spotName']),
        ),
        body: l10n.notificationNearbyTrainingPlanBody,
      );
    default:
      return UserNotificationCopy(
        title: notification.title,
        body: notification.body,
      );
  }
}
