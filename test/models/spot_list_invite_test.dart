import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_list_invite.dart';

void main() {
  group('SpotListInvite', () {
    test('fromMap parses role and status', () {
      final invite = SpotListInvite.fromMap('inv-1', {
        'listId': 'list-1',
        'listName': 'Jam',
        'inviterUid': 'owner',
        'inviteeUid': 'friend',
        'role': 'edit',
        'status': 'pending',
      });
      expect(invite.id, 'inv-1');
      expect(invite.role, SpotListInviteRole.edit);
      expect(invite.status, SpotListInviteStatus.pending);
      expect(invite.status.isActive, isTrue);
    });

    test('declined and left are not active', () {
      expect(SpotListInviteStatus.declined.isActive, isFalse);
      expect(SpotListInviteStatus.left.isActive, isFalse);
      expect(SpotListInviteStatus.revoked.isActive, isFalse);
      expect(SpotListInviteStatus.accepted.isActive, isTrue);
    });
  });
}
