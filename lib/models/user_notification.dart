import 'package:cloud_firestore/cloud_firestore.dart';

enum UserNotificationDeeplinkKind {
  spot,
  profile,
}

class UserNotification {
  const UserNotification({
    required this.id,
    required this.title,
    required this.deeplinkKind,
    required this.deeplinkId,
    this.body,
    this.createdAt,
    this.read = false,
    this.readAt,
  });

  final String id;
  final String title;
  final String? body;
  final UserNotificationDeeplinkKind deeplinkKind;
  final String deeplinkId;
  final DateTime? createdAt;
  final bool read;
  final DateTime? readAt;

  factory UserNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String?,
      deeplinkKind: _deeplinkKindFromString(data['deeplinkKind'] as String?),
      deeplinkId: data['deeplinkId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      read: data['read'] as bool? ?? false,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }

  static UserNotificationDeeplinkKind _deeplinkKindFromString(String? raw) {
    switch (raw) {
      case 'profile':
        return UserNotificationDeeplinkKind.profile;
      case 'spot':
      default:
        return UserNotificationDeeplinkKind.spot;
    }
  }
}
