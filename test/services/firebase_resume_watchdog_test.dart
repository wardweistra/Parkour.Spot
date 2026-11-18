import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/firebase_resume_watchdog.dart';

void main() {
  group('FirebaseResumeWatchdog.shouldReload', () {
    final now = DateTime.utc(2026, 11, 17, 15, 0);

    test('reloads when it never reloaded before', () {
      expect(
        FirebaseResumeWatchdog.shouldReload(lastReloadAt: null, now: now),
        isTrue,
      );
    });

    test('does not reload again within the minimum interval', () {
      expect(
        FirebaseResumeWatchdog.shouldReload(
          lastReloadAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('reloads again once the minimum interval has passed', () {
      expect(
        FirebaseResumeWatchdog.shouldReload(
          lastReloadAt: now.subtract(FirebaseResumeWatchdog.minReloadInterval),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('FirebaseResumeWatchdog.findStalledProbes', () {
    const timeout = Duration(milliseconds: 50);

    test('reports only probes that never settle', () async {
      final stalled = await FirebaseResumeWatchdog.findStalledProbes({
        'ok': () async => 'token',
        'hangs': () => Completer<String>().future,
      }, timeout);
      expect(stalled, ['hangs']);
    });

    test('a probe that throws has answered and is not stalled', () async {
      final stalled = await FirebaseResumeWatchdog.findStalledProbes({
        'fails': () async => throw StateError('network-request-failed'),
      }, timeout);
      expect(stalled, isEmpty);
    });

    test('no probes means nothing stalled', () async {
      expect(
        await FirebaseResumeWatchdog.findStalledProbes({}, timeout),
        isEmpty,
      );
    });
  });
}
