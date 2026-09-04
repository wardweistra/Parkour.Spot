import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/admin_notifications_service.dart';

void main() {
  test('load diagnostics include callable error and admin sources', () {
    final text = formatAdminNotificationsLoadDiagnostics(
      error: StateError('FAILED_PRECONDITION: requires an index'),
      uid: 'user-1',
      adminClaim: null,
      firestoreIsAdmin: true,
    );

    expect(text, contains('callable error: Bad state: FAILED_PRECONDITION: requires an index'));
    expect(text, contains('FirebaseAuth.currentUser.uid: user-1'));
    expect(text, contains('claim admin: null'));
    expect(text, contains('Firestore users/{uid}.isAdmin: true'));
    expect(text, contains('A null admin claim is OK when Firestore isAdmin is true'));
    expect(text, contains('fieldOverrides'));
  });
}
