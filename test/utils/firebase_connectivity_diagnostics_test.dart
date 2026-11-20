import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/firebase_connectivity_diagnostics.dart';

void main() {
  test(
    'formatFirebaseConnectivityDiagnostics includes snapshot and probes',
    () {
      final text = formatFirebaseConnectivityDiagnostics(
        snapshot: {
          'timestamp': '2026-11-15T19:00:00.000Z',
          'href': 'https://app.parkourspot.com/',
          'auth.uid': 'user-1',
        },
        probes: [
          const FirebaseConnectivityProbeResult(
            name: 'Auth cached token',
            passed: true,
            durationMs: 12,
            details: {'expiresInSeconds': '3400'},
          ),
          const FirebaseConnectivityProbeResult(
            name: 'Callable getTopSpotsInBounds',
            passed: false,
            durationMs: 15000,
            details: {'FirebaseFunctionsException.code': 'deadline-exceeded'},
            error: 'FirebaseFunctionsException: deadline-exceeded',
          ),
        ],
      );

      expect(text, contains('=== Firebase connectivity diagnostics ==='));
      expect(text, contains('timestamp: 2026-11-15T19:00:00.000Z'));
      expect(text, contains('href: https://app.parkourspot.com/'));
      expect(text, contains('auth.uid: user-1'));
      expect(text, contains('[PASS] Auth cached token (12ms)'));
      expect(text, contains('expiresInSeconds: 3400'));
      expect(text, contains('[FAIL] Callable getTopSpotsInBounds (15000ms)'));
      expect(
        text,
        contains('FirebaseFunctionsException.code: deadline-exceeded'),
      );
      expect(
        text,
        contains('error: FirebaseFunctionsException: deadline-exceeded'),
      );
      expect(
        text,
        contains(
          'Auth refresh fails, Firestore OK → Auth/session after resume.',
        ),
      );
    },
  );
}
