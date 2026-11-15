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
  b.writeln(
    'Auth refresh fails, Firestore OK → Auth/session after resume.',
  );
  b.writeln(
    'Auth OK, Firestore OK, callable fails (unauthenticated / '
    'deadline-exceeded / network) → callable transport or token attachment.',
  );
  b.writeln(
    'Auth OK, Firestore fails too → broader offline/session problem.',
  );
  b.writeln(
    'App Check fails alone → ignore unless only Places callables break.',
  );
  return b.toString();
}
