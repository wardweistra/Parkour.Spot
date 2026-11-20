import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/firebase_resume_watchdog.dart';
import '../../utils/browser_location.dart';
import '../../utils/browser_network_probes.dart';
import '../../utils/firebase_connectivity_diagnostics.dart';

/// Admin page to diagnose idle/resume failures of Auth, Firestore, and callables.
class FirebaseConnectivityScreen extends StatefulWidget {
  const FirebaseConnectivityScreen({super.key});

  @override
  State<FirebaseConnectivityScreen> createState() =>
      _FirebaseConnectivityScreenState();
}

class _FirebaseConnectivityScreenState
    extends State<FirebaseConnectivityScreen> {
  static const _probeTimeout = Duration(seconds: 15);

  /// Tiny Amsterdam bbox — enough for getTopSpotsInBounds without heavy work.
  static const _pingMinLat = 52.37;
  static const _pingMaxLat = 52.38;
  static const _pingMinLng = 4.88;
  static const _pingMaxLng = 4.90;

  bool _running = false;
  Map<String, String> _snapshot = {};
  List<FirebaseConnectivityProbeResult> _probes = [];
  String? _lastFormatted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runAllProbes();
      }
    });
  }

  Map<String, String> _buildSnapshot() {
    final user = FirebaseAuth.instance.currentUser;
    const useEmulator = bool.fromEnvironment('USE_EMULATOR');
    const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
    final standalone = browserMatchMedia('(display-mode: standalone)');
    final visibility = browserVisibilityState();
    final online = browserNavigatorOnLine();

    return {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'href': browserHref() ?? '(n/a)',
      'displayMode': standalone == null
          ? '(n/a)'
          : (standalone ? 'standalone' : 'browser'),
      'visibilityState': visibility ?? '(n/a)',
      'navigator.onLine': online?.toString() ?? '(n/a)',
      'auth.uid': user?.uid ?? '(signed out)',
      'auth.email': user?.email ?? '(none)',
      'auth.providers': user == null
          ? '(none)'
          : user.providerData.map((p) => p.providerId).join(', '),
      'USE_EMULATOR': useEmulator.toString(),
      'RECAPTCHA_SITE_KEY_present': recaptchaSiteKey.isNotEmpty.toString(),
      ...FirebaseResumeWatchdog.diagnostics(),
    };
  }

  /// Checks below the Firebase SDKs: can the page reach Google at all, and
  /// does IndexedDB (which Auth, App Check and heartbeats use) still answer?
  Future<FirebaseConnectivityProbeResult> _probeRaw(
    String name,
    Future<String> Function() run,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final result = await run().timeout(_probeTimeout);
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: name,
        passed: true,
        durationMs: sw.elapsedMilliseconds,
        details: {'result': result},
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: name,
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Future<FirebaseConnectivityProbeResult> _probeAuthCached() async {
    final sw = Stopwatch()..start();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth cached token',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: 'Signed out',
      );
    }
    try {
      final result = await user.getIdTokenResult(false).timeout(_probeTimeout);
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth cached token',
        passed: true,
        durationMs: sw.elapsedMilliseconds,
        details: _tokenDetails(result),
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth cached token',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Future<FirebaseConnectivityProbeResult> _probeAuthForceRefresh() async {
    final sw = Stopwatch()..start();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth force refresh',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: 'Signed out',
      );
    }
    try {
      final result = await user.getIdTokenResult(true).timeout(_probeTimeout);
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth force refresh',
        passed: true,
        durationMs: sw.elapsedMilliseconds,
        details: _tokenDetails(result),
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Auth force refresh',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Map<String, String> _tokenDetails(IdTokenResult result) {
    final expiration = result.expirationTime;
    final now = DateTime.now();
    final details = <String, String>{
      'authTime': result.authTime?.toUtc().toIso8601String() ?? '(null)',
      'issuedAt': result.issuedAtTime?.toUtc().toIso8601String() ?? '(null)',
      'expirationTime': expiration?.toUtc().toIso8601String() ?? '(null)',
      'claim.admin': '${result.claims?['admin']}',
      'signInProvider': result.signInProvider ?? '(null)',
    };
    if (expiration != null) {
      details['expiresInSeconds'] = expiration
          .difference(now)
          .inSeconds
          .toString();
    }
    return details;
  }

  Future<FirebaseConnectivityProbeResult> _probeFirestore() async {
    final sw = Stopwatch()..start();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Firestore server read',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: 'Signed out',
      );
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_probeTimeout);
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Firestore server read',
        passed: true,
        durationMs: sw.elapsedMilliseconds,
        details: {
          'path': 'users/${user.uid}',
          'exists': doc.exists.toString(),
          'isAdmin': '${doc.data()?['isAdmin']}',
        },
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Firestore server read',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Future<FirebaseConnectivityProbeResult> _probeCallable() async {
    final sw = Stopwatch()..start();
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getTopSpotsInBounds');
      final result = await callable
          .call(<String, dynamic>{
            'minLat': _pingMinLat,
            'maxLat': _pingMaxLat,
            'minLng': _pingMinLng,
            'maxLng': _pingMaxLng,
            'limit': 1,
          })
          .timeout(_probeTimeout);
      sw.stop();
      final raw = result.data;
      final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final success = data?['success'] == true;
      final spots = data?['spots'];
      final spotCount = spots is List ? spots.length : null;
      return FirebaseConnectivityProbeResult(
        name: 'Callable getTopSpotsInBounds',
        passed: success,
        durationMs: sw.elapsedMilliseconds,
        details: {
          'success': '${data?['success']}',
          'shownCount': '${data?['shownCount']}',
          'spotsReturned': '$spotCount',
          if (data?['error'] != null) 'response.error': '${data?['error']}',
        },
        error: success ? null : '${data?['error'] ?? 'success != true'}',
      );
    } on FirebaseFunctionsException catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Callable getTopSpotsInBounds',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        details: {
          'FirebaseFunctionsException.code': e.code,
          'FirebaseFunctionsException.message': e.message ?? '(null)',
          if (e.details != null)
            'FirebaseFunctionsException.details': '${e.details}',
        },
        error: e.toString(),
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'Callable getTopSpotsInBounds',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Future<FirebaseConnectivityProbeResult> _probeAppCheck() async {
    final sw = Stopwatch()..start();
    try {
      final token = await FirebaseAppCheck.instance.getToken().timeout(
        _probeTimeout,
      );
      sw.stop();
      final present = token != null && token.isNotEmpty;
      return FirebaseConnectivityProbeResult(
        name: 'App Check token',
        passed: present,
        durationMs: sw.elapsedMilliseconds,
        details: {
          'tokenPresent': present.toString(),
          'tokenLength': present ? '${token.length}' : '0',
        },
        error: present
            ? null
            : 'No App Check token (may be inactive in this build)',
      );
    } catch (e) {
      sw.stop();
      return FirebaseConnectivityProbeResult(
        name: 'App Check token',
        passed: false,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  Future<void> _runAllProbes() async {
    if (_running) return;
    setState(() {
      _running = true;
      _snapshot = _buildSnapshot();
      _probes = [];
      _lastFormatted = null;
    });

    final rawProbes = await Future.wait([
      _probeRaw(
        'Raw fetch securetoken.googleapis.com',
        () => browserProbeFetch('https://securetoken.googleapis.com/'),
      ),
      _probeRaw(
        'Raw fetch content-firebaseappcheck.googleapis.com',
        () => browserProbeFetch(
          'https://content-firebaseappcheck.googleapis.com/',
        ),
      ),
      _probeRaw('Raw IndexedDB write', browserProbeIndexedDb),
    ]);

    // App Check first: Auth refreshes, Firestore and callables all wait on it.
    final probes = <FirebaseConnectivityProbeResult>[
      ...rawProbes,
      await _probeAppCheck(),
      await _probeAuthCached(),
      await _probeAuthForceRefresh(),
      await _probeFirestore(),
      await _probeCallable(),
    ];

    if (!mounted) return;
    final formatted = formatFirebaseConnectivityDiagnostics(
      snapshot: _snapshot,
      probes: probes,
    );
    setState(() {
      _probes = probes;
      _lastFormatted = formatted;
      _running = false;
    });
  }

  Future<void> _forceTokenRefreshOnly() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await _probeAuthForceRefresh();
    if (!mounted) return;

    final probes = List<FirebaseConnectivityProbeResult>.from(_probes);
    final idx = probes.indexWhere((p) => p.name == 'Auth force refresh');
    if (idx >= 0) {
      probes[idx] = result;
    } else {
      probes.add(result);
    }
    final snapshot = _buildSnapshot();
    final formatted = formatFirebaseConnectivityDiagnostics(
      snapshot: snapshot,
      probes: probes,
    );
    setState(() {
      _snapshot = snapshot;
      _probes = probes;
      _lastFormatted = formatted;
      _running = false;
    });
  }

  Future<void> _copyDiagnostics() async {
    final text =
        _lastFormatted ??
        formatFirebaseConnectivityDiagnostics(
          snapshot: _snapshot.isEmpty ? _buildSnapshot() : _snapshot,
          probes: _probes,
        );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firebase connectivity')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 12),
                const Text('Administrator access required'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/explore?tab=profile'),
                  child: const Text('Back to profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase connectivity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/admin');
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _runAllProbes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? null : _runAllProbes,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_running ? 'Running…' : 'Run probes'),
                ),
                OutlinedButton.icon(
                  onPressed: _running ? null : _forceTokenRefreshOnly,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Force token refresh'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyDiagnostics,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy diagnostics'),
                ),
                OutlinedButton.icon(
                  onPressed: browserReload,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reload app'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to read this',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      firebaseConnectivityInterpretation.join('\n'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Snapshot',
              child: _snapshot.isEmpty
                  ? const Text('Waiting for first run…')
                  : Column(
                      children: _snapshot.entries
                          .map((e) => _InfoRow(label: e.key, value: e.value))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Probes',
              child: _probes.isEmpty
                  ? Text(_running ? 'Running probes…' : 'No probe results yet')
                  : Column(
                      children: [
                        for (var i = 0; i < _probes.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _ProbeTile(probe: _probes[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbeTile extends StatelessWidget {
  const _ProbeTile({required this.probe});

  final FirebaseConnectivityProbeResult probe;

  @override
  Widget build(BuildContext context) {
    final color = probe.passed
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              probe.passed ? Icons.check_circle : Icons.error,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                probe.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${probe.durationMs}ms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in probe.details.entries)
          _InfoRow(label: entry.key, value: entry.value),
        if (probe.error != null && probe.error!.isNotEmpty)
          _InfoRow(label: 'error', value: probe.error!),
      ],
    );
  }
}
