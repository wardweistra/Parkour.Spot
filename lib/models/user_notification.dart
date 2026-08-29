import 'package:cloud_firestore/cloud_firestore.dart';

enum UserNotificationDeeplinkKind { spot, event, profile }

class UserNotification {
  const UserNotification({
    required this.id,
    required this.title,
    required this.deeplinkKind,
    required this.deeplinkId,
    this.notificationKind,
    this.templateArgs,
    this.body,
    this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String? body;

  /// Backend stable id for localized inbox copy (e.g. `nearby_new_spot`).
  final String? notificationKind;

  /// Parameters for [notificationKind] templates (`actorName`, `spotName`, `eventName`).
  final Map<String, String>? templateArgs;
  final UserNotificationDeeplinkKind deeplinkKind;
  final String deeplinkId;
  final DateTime? createdAt;
  final bool read;

  factory UserNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String?,
      notificationKind: data['notificationKind'] as String?,
      templateArgs: _templateArgsFromFirestore(data['templateArgs']),
      deeplinkKind: _deeplinkKindFromString(data['deeplinkKind'] as String?),
      deeplinkId: data['deeplinkId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      read: data['read'] as bool? ?? false,
    );
  }

  /// Payload from [listInAppNotificationsForAdmin] callable (plain JSON maps).
  factory UserNotification.fromAdminCallable(
    String id,
    Map<String, dynamic> data,
  ) {
    return UserNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String?,
      notificationKind: data['notificationKind'] as String?,
      templateArgs: _templateArgsFromFirestore(data['templateArgs']),
      deeplinkKind: _deeplinkKindFromString(data['deeplinkKind'] as String?),
      deeplinkId: data['deeplinkId'] as String? ?? '',
      createdAt: data['createdAtMillis'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['createdAtMillis'] as num).toInt(),
              isUtc: true,
            )
          : null,
      read: data['read'] as bool? ?? false,
    );
  }

  static Map<String, String>? _templateArgsFromFirestore(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, String>{};
    for (final key in const ['actorName', 'spotName', 'eventName']) {
      final v = raw[key];
      if (v is String) {
        out[key] = v;
      }
    }
    return out.isEmpty ? null : out;
  }

  static UserNotificationDeeplinkKind _deeplinkKindFromString(String? raw) {
    switch (raw) {
      case 'profile':
        return UserNotificationDeeplinkKind.profile;
      case 'event':
        return UserNotificationDeeplinkKind.event;
      case 'spot':
      default:
        return UserNotificationDeeplinkKind.spot;
    }
  }
}
