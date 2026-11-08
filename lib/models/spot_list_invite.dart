import 'package:cloud_firestore/cloud_firestore.dart';

enum SpotListInviteRole {
  edit,
  view;

  static SpotListInviteRole fromString(String? value) {
    switch (value) {
      case 'edit':
        return SpotListInviteRole.edit;
      case 'view':
      default:
        return SpotListInviteRole.view;
    }
  }

  String get firestoreValue {
    switch (this) {
      case SpotListInviteRole.edit:
        return 'edit';
      case SpotListInviteRole.view:
        return 'view';
    }
  }
}

enum SpotListInviteStatus {
  pending,
  accepted,
  declined,
  revoked,
  left;

  static SpotListInviteStatus fromString(String? value) {
    switch (value) {
      case 'accepted':
        return SpotListInviteStatus.accepted;
      case 'declined':
        return SpotListInviteStatus.declined;
      case 'revoked':
        return SpotListInviteStatus.revoked;
      case 'left':
        return SpotListInviteStatus.left;
      case 'pending':
      default:
        return SpotListInviteStatus.pending;
    }
  }

  String get firestoreValue {
    switch (this) {
      case SpotListInviteStatus.pending:
        return 'pending';
      case SpotListInviteStatus.accepted:
        return 'accepted';
      case SpotListInviteStatus.declined:
        return 'declined';
      case SpotListInviteStatus.revoked:
        return 'revoked';
      case SpotListInviteStatus.left:
        return 'left';
    }
  }

  bool get isActive =>
      this == SpotListInviteStatus.pending ||
      this == SpotListInviteStatus.accepted;
}

class SpotListInvite {
  const SpotListInvite({
    required this.id,
    required this.listId,
    required this.listName,
    required this.inviterUid,
    required this.inviteeUid,
    required this.role,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String listId;
  final String listName;
  final String inviterUid;
  final String inviteeUid;
  final SpotListInviteRole role;
  final SpotListInviteStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  factory SpotListInvite.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : (raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{});
    return SpotListInvite.fromMap(doc.id, data);
  }

  factory SpotListInvite.fromMap(String id, Map<String, dynamic> data) {
    return SpotListInvite(
      id: id,
      listId: data['listId'] as String? ?? '',
      listName: data['listName'] as String? ?? '',
      inviterUid: data['inviterUid'] as String? ?? '',
      inviteeUid: data['inviteeUid'] as String? ?? '',
      role: SpotListInviteRole.fromString(data['role'] as String?),
      status: SpotListInviteStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
