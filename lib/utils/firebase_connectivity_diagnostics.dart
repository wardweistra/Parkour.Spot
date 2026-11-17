/// Result of one Firebase connectivity probe for the admin diagnostics screen.
class FirebaseConnectivityProbeResult {
  const FirebaseConnectivityProbeResult({
    required this.name,
    required this.passed,
    required this.durationMs,
    this.details = const {},
    this.error,
  });

  final String name;
  final bool passed;
  final int durationMs;
  final Map<String, String> details;
  final String? error;
}

/// How to read probe outcomes; shown on the screen and in the copied dump.
const firebaseConnectivityInterpretation = <String>[
  'Raw fetch fails → the network itself, not Firebase.',
  'Raw IndexedDB times out → browser storage is wedged; Firebase waits on it.',
  'Raw checks OK, but App Check, Auth and the callable time out and Firestore '
      'is unavailable → Firebase token pipeline wedged (App Check exchange '
      'stuck after resume). The resume watchdog should reload the app; see '
      'watchdog.* in the snapshot.',
  'Auth refresh fails, Firestore OK → Auth/session after resume.',
  'Auth OK, Firestore OK, callable fails (unauthenticated / '
      'deadline-exceeded / network) → callable transport or token attachment.',
  'Auth OK, Firestore fails too → broader offline/session problem.',
  'App Check fails alone → ignore unless only Places callables break.',
];

/// Plain-text dump for clipboard when idle/resume callables stop working.
String formatFirebaseConnectivityDiagnostics({
  required Map<String, String> snapshot,
  required List<FirebaseConnectivityProbeResult> probes,
}) {
  final b = StringBuffer();
  b.writeln('=== Firebase connectivity diagnostics ===');
  b.writeln();
  b.writeln('--- Snapshot ---');
  for (final entry in snapshot.entries) {
    b.writeln('${entry.key}: ${entry.value}');
  }
  b.writeln();
  b.writeln('--- Probes ---');
  for (final probe in probes) {
    b.writeln();
    b.writeln('[${probe.passed ? 'PASS' : 'FAIL'}] ${probe.name} (${probe.durationMs}ms)');
    for (final entry in probe.details.entries) {
      b.writeln('  ${entry.key}: ${entry.value}');
    }
    if (probe.error != null && probe.error!.isNotEmpty) {
      b.writeln('  error: ${probe.error}');
    }
  }
  b.writeln();
  b.writeln('--- Interpretation ---');
  for (final line in firebaseConnectivityInterpretation) {
    b.writeln(line);
  }
  return b.toString();
}
