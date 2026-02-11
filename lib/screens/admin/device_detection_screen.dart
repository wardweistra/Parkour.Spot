import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import '../../services/auth_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/pwa_install_service.dart';

// Helper function to call eval via JS interop (similar to web_analytics.dart)
@JS('eval')
external JSAny _eval(JSString code);

class DeviceDetectionScreen extends StatefulWidget {
  const DeviceDetectionScreen({super.key});

  @override
  State<DeviceDetectionScreen> createState() => _DeviceDetectionScreenState();
}

class _DeviceDetectionScreenState extends State<DeviceDetectionScreen> {
  Map<String, dynamic>? _deviceInfo;
  Map<String, dynamic>? _pwaInfo;
  Map<String, dynamic>? _pwaDiagnostics;
  bool _isLoadingServiceWorker = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  void _loadInfo() {
    setState(() {
      _deviceInfo = MobileDetectionService.detailedDeviceInfo;
      _pwaInfo = _getPwaDebugInfo();
      _pwaDiagnostics = _getPwaDiagnostics();
    });
    _checkServiceWorkerStatus();
  }

  Future<void> _checkServiceWorkerStatus() async {
    if (!kIsWeb) return;
    
    setState(() {
      _isLoadingServiceWorker = true;
    });

    try {
      final diagnostics = Map<String, dynamic>.from(_pwaDiagnostics ?? {});
      
      // Check service worker registration using eval (WASM-compatible)
      try {
        // Store result in window object temporarily, then read it back
        final checkCode = '''
          (async function() {
            try {
              const registrations = await navigator.serviceWorker.getRegistrations();
              let result;
              if (registrations.length > 0) {
                const reg = registrations[0];
                result = {
                  registered: true,
                  count: registrations.length,
                  scope: reg.scope,
                  active: reg.active ? {
                    state: reg.active.state,
                    scriptURL: reg.active.scriptURL
                  } : null,
                  installing: reg.installing ? { state: reg.installing.state } : null,
                  waiting: reg.waiting ? { state: reg.waiting.state } : null
                };
              } else {
                result = { registered: false, count: 0 };
              }
              window._pwaDiagnosticsSW = JSON.stringify(result);
              return true;
            } catch (e) {
              window._pwaDiagnosticsSW = JSON.stringify({ error: e.toString() });
              return false;
            }
          })()
        '''.toJS;
        
        _eval(checkCode);
        
        // Wait a bit for async operation, then read result
        await Future.delayed(const Duration(milliseconds: 500));
        
        final readCode = 'window._pwaDiagnosticsSW || "{}"'.toJS;
        final resultJsonJS = _eval(readCode);
        final resultJson = (resultJsonJS as JSString).toDart;
        
        // Parse JSON using dart:convert
        final result = jsonDecode(resultJson) as Map<String, dynamic>;
        
        // Access properties from result
        final registered = result['registered'] as bool? ?? false;
        diagnostics['serviceWorkerRegistered'] = registered;
        
        if (registered) {
          diagnostics['serviceWorkerRegistrationsCount'] = result['count'] as int? ?? 0;
          diagnostics['serviceWorkerScope'] = result['scope'] as String? ?? 'unknown';
          
          final active = result['active'];
          if (active != null) {
            diagnostics['serviceWorkerActive'] = true;
            final activeMap = active as Map<String, dynamic>;
            diagnostics['serviceWorkerActiveState'] = activeMap['state'] as String? ?? 'unknown';
            diagnostics['serviceWorkerActiveScriptURL'] = activeMap['scriptURL'] as String? ?? 'unknown';
          } else {
            diagnostics['serviceWorkerActive'] = false;
          }
          
          final installing = result['installing'];
          diagnostics['serviceWorkerInstalling'] = installing != null;
          if (installing != null) {
            final installingMap = installing as Map<String, dynamic>;
            diagnostics['serviceWorkerInstallingState'] = installingMap['state'] as String? ?? 'unknown';
          }
          
          final waiting = result['waiting'];
          diagnostics['serviceWorkerWaiting'] = waiting != null;
          if (waiting != null) {
            final waitingMap = waiting as Map<String, dynamic>;
            diagnostics['serviceWorkerWaitingState'] = waitingMap['state'] as String? ?? 'unknown';
          }
        } else {
          final error = result['error'];
          if (error != null) {
            diagnostics['serviceWorkerError'] = error.toString();
          } else {
            diagnostics['serviceWorkerError'] = 'No service worker registrations found';
          }
        }
      } catch (e) {
        diagnostics['serviceWorkerCheckError'] = e.toString();
      }
      
      // Check manifest validity using eval (WASM-compatible)
      try {
        final manifestLink = web.document.querySelector('link[rel="manifest"]');
        if (manifestLink != null) {
          final manifestHref = (manifestLink as web.HTMLLinkElement).href;
          // Escape quotes in href for use in JS string
          final escapedHref = manifestHref.replaceAll('"', '\\"');
          
          final checkCode = '''
            (async function() {
              try {
                const response = await fetch("$escapedHref");
                if (!response.ok) {
                  window._pwaDiagnosticsManifest = JSON.stringify({ accessible: false, status: response.status });
                  return;
                }
                const text = await response.text();
                const manifest = JSON.parse(text);
                window._pwaDiagnosticsManifest = JSON.stringify({
                  accessible: true,
                  size: text.length,
                  validJSON: true,
                  hasName: !!manifest.name,
                  hasIcons: !!manifest.icons,
                  displayMode: manifest.display || 'not set',
                  iconsCount: manifest.icons ? manifest.icons.length : 0,
                  has192Icon: manifest.icons ? manifest.icons.some(i => i.sizes && i.sizes.includes('192')) : false,
                  has512Icon: manifest.icons ? manifest.icons.some(i => i.sizes && i.sizes.includes('512')) : false
                });
              } catch (e) {
                window._pwaDiagnosticsManifest = JSON.stringify({ accessible: false, error: e.toString() });
              }
            })()
          '''.toJS;
          
          _eval(checkCode);
          
          // Wait a bit for async operation, then read result
          await Future.delayed(const Duration(milliseconds: 500));
          
          final readCode = 'window._pwaDiagnosticsManifest || "{}"'.toJS;
          final resultJsonJS = _eval(readCode);
          final resultJson = (resultJsonJS as JSString).toDart;
          
          // Parse JSON using dart:convert
          final result = jsonDecode(resultJson) as Map<String, dynamic>;
          
          final accessible = result['accessible'] as bool? ?? false;
          diagnostics['manifestAccessible'] = accessible;
          
          if (accessible) {
            diagnostics['manifestSize'] = '${result['size'] as int? ?? 0} bytes';
            diagnostics['manifestValidJSON'] = result['validJSON'] as bool? ?? false;
            diagnostics['manifestHasName'] = result['hasName'] as bool? ?? false;
            diagnostics['manifestHasIcons'] = result['hasIcons'] as bool? ?? false;
            diagnostics['manifestDisplayMode'] = result['displayMode'] as String? ?? 'not set';
            diagnostics['manifestIconsCount'] = result['iconsCount'] as int? ?? 0;
            diagnostics['manifestHas192Icon'] = result['has192Icon'] as bool? ?? false;
            diagnostics['manifestHas512Icon'] = result['has512Icon'] as bool? ?? false;
          } else {
            final status = result['status'];
            final error = result['error'];
            if (status != null) {
              diagnostics['manifestResponseStatus'] = status.toString();
            }
            if (error != null) {
              diagnostics['manifestFetchError'] = error.toString();
            }
          }
        }
      } catch (e) {
        diagnostics['manifestCheckError'] = e.toString();
      }
      
      setState(() {
        _pwaDiagnostics = diagnostics;
        _isLoadingServiceWorker = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingServiceWorker = false;
        if (_pwaDiagnostics != null) {
          _pwaDiagnostics!['checkError'] = e.toString();
        }
      });
    }
  }

  Map<String, dynamic> _getPwaDebugInfo() {
    if (!kIsWeb) {
      return {'error': 'Not available on non-web platforms'};
    }

    try {
      final pwaService = PwaInstallService();
      return pwaService.debugInfo;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void _testInstallInstructions() {
    if (!kIsWeb) return;
    
    final pwaService = PwaInstallService();
    
    if (pwaService.isInstalled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App is already installed as PWA'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Always show instructions dialog (platform-specific)
    final instructions = MobileDetectionService.isIOS
        ? pwaService.getIOSInstallInstructions()
        : pwaService.getAndroidInstallInstructions();
    
    final platformName = MobileDetectionService.isIOS ? 'iPhone' : 'Android device';
    
    _showInstallInstructionsDialog(instructions, platformName);
  }

  void _testIOSInstructions() {
    if (!kIsWeb) return;
    
    final pwaService = PwaInstallService();
    final instructions = pwaService.getIOSInstallInstructions();
    
    _showInstallInstructionsDialog(instructions, 'iPhone');
  }

  void _showInstallInstructionsDialog(Map<String, String> instructions, String platformName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.get_app, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(instructions['title']!)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To install Parkour·Spot on your $platformName:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep('1', instructions['step1']!),
            const SizedBox(height: 12),
            _buildInstructionStep('2', instructions['step2']!),
            const SizedBox(height: 12),
            _buildInstructionStep('3', instructions['step3']!),
            const SizedBox(height: 12),
            _buildInstructionStep('4', instructions['step4']!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _copyDiagnosticsToClipboard() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('=== Device Detection Diagnostics ===');
      buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('');
      
      // Mobile Detection Service Info
      buffer.writeln('--- Mobile Detection Service ---');
      if (_deviceInfo != null) {
        for (final entry in _deviceInfo!.entries) {
          buffer.writeln('${entry.key}: ${entry.value}');
        }
      }
      buffer.writeln('');
      
      // PWA Install Service Info
      buffer.writeln('--- PWA Install Service ---');
      if (_pwaInfo != null) {
        for (final entry in _pwaInfo!.entries) {
          buffer.writeln('${entry.key}: ${_formatValueForCopy(entry.key, entry.value)}');
        }
      }
      buffer.writeln('');
      
      // PWA Diagnostics
      buffer.writeln('--- PWA Diagnostics ---');
      if (_pwaDiagnostics != null) {
        for (final entry in _pwaDiagnostics!.entries) {
          buffer.writeln('${entry.key}: ${_formatValueForCopy(entry.key, entry.value)}');
        }
      }
      buffer.writeln('');
      
      // Quick Status
      buffer.writeln('--- Quick Status ---');
      buffer.writeln('Is Mobile Device: ${MobileDetectionService.isMobileDevice}');
      buffer.writeln('Is iOS: ${MobileDetectionService.isIOS}');
      buffer.writeln('Is Android: ${MobileDetectionService.isAndroid}');
      buffer.writeln('Running as PWA: ${MobileDetectionService.isRunningAsPWA}');
      buffer.writeln('Running in Browser: ${MobileDetectionService.isRunningInBrowser}');
      if (kIsWeb) {
        buffer.writeln('PWA Install Prompt Should Show: ${PwaInstallService().shouldShowPrompt}');
      }
      
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diagnostics copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy diagnostics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatValueForCopy(String key, dynamic value) {
    // Format timestamps
    if (key.contains('Timestamp') && value != null && value is int) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(value);
        final now = DateTime.now();
        final diff = now.difference(date);
        return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(date)} (${_formatDuration(diff)} ago)';
      } catch (e) {
        return value.toString();
      }
    }
    
    // Format booleans
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    
    // Format null
    if (value == null) {
      return 'null';
    }
    
    return value.toString();
  }

  Map<String, dynamic> _getPwaDiagnostics() {
    if (!kIsWeb) {
      return {'error': 'Not available on non-web platforms'};
    }

    try {
      final diagnostics = <String, dynamic>{};
      
      // Check HTTPS
      final isHttps = web.window.location.protocol == 'https:';
      final isLocalhost = web.window.location.hostname == 'localhost' || 
                         web.window.location.hostname == '127.0.0.1';
      diagnostics['isHTTPS'] = isHttps;
      diagnostics['isLocalhost'] = isLocalhost;
      diagnostics['protocol'] = web.window.location.protocol;
      diagnostics['hostname'] = web.window.location.hostname;
      diagnostics['fullURL'] = web.window.location.href;
      
      // Check if service worker is supported
      try {
        // Access serviceWorker to verify API exists (will throw if not available)
        web.window.navigator.serviceWorker;
        diagnostics['serviceWorkerSupported'] = true;
        diagnostics['serviceWorkerAPIAvailable'] = true;
        // Note: Actual registration status is checked asynchronously in _checkServiceWorkerStatus
      } catch (e) {
        diagnostics['serviceWorkerSupported'] = false;
        diagnostics['serviceWorkerAPIAvailable'] = false;
        diagnostics['serviceWorkerError'] = e.toString();
      }
      
      // Check manifest
      try {
        final manifestLink = web.document.querySelector('link[rel="manifest"]');
        diagnostics['manifestLinkExists'] = manifestLink != null;
        if (manifestLink != null) {
          diagnostics['manifestHref'] = (manifestLink as web.HTMLLinkElement).href;
        }
      } catch (e) {
        diagnostics['manifestLinkError'] = e.toString();
      }
      
      // Check standalone display mode support
      try {
        final standaloneMatch = web.window.matchMedia('(display-mode: standalone)');
        diagnostics['standaloneDisplayModeSupported'] = true;
        diagnostics['standaloneDisplayModeMatches'] = standaloneMatch.matches;
      } catch (e) {
        diagnostics['standaloneDisplayModeSupported'] = false;
      }
      
      // Check if app is installable (heuristic based on common requirements)
      final meetsBasicRequirements = isHttps || isLocalhost;
      diagnostics['meetsBasicRequirements'] = meetsBasicRequirements;
      
      return diagnostics;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Detection')),
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
                  child: const Text('Back to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Detection Info'),
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
        onRefresh: () async {
          _loadInfo();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _copyDiagnosticsToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadInfo,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Mobile Detection Service Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mobile Detection Service',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_deviceInfo != null)
                        ..._deviceInfo!.entries.map((entry) => _buildInfoRow(
                          context,
                          entry.key,
                          entry.value.toString(),
                        )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // PWA Install Service Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.get_app,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PWA Install Service',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Test install instructions buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testInstallInstructions,
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: Text(MobileDetectionService.isIOS 
                                  ? 'Test iOS Instructions'
                                  : 'Test Android Instructions'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testIOSInstructions,
                              icon: const Icon(Icons.phone_iphone, size: 18),
                              label: const Text('Test iOS Instructions'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_pwaInfo != null)
                        ..._pwaInfo!.entries.map((entry) => _buildInfoRow(
                          context,
                          entry.key,
                          _formatValue(entry.key, entry.value),
                        )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // PWA Diagnostics
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PWA Diagnostics',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingServiceWorker)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_pwaDiagnostics != null)
                        ..._pwaDiagnostics!.entries.map((entry) => _buildInfoRow(
                          context,
                          entry.key,
                          _formatValue(entry.key, entry.value),
                        )),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Install Instructions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDiagnosticTip(context, 'iOS', 'Users see manual install instructions via Share button'),
                      _buildDiagnosticTip(context, 'Android', 'Users see manual install instructions via More menu'),
                      _buildDiagnosticTip(context, 'Chrome install button', 'Chrome may show its own install button in the address bar if installability criteria are met'),
                      _buildDiagnosticTip(context, 'Profile banner', 'Install banner always shows on Profile tab for mobile users not on PWA'),
                      _buildDiagnosticTip(context, 'Explore banner', 'Install banner shows on Explore tab after user engagement (page views, time)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Quick Status Summary
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        context,
                        'Is Mobile Device',
                        MobileDetectionService.isMobileDevice,
                      ),
                      _buildStatusRow(
                        context,
                        'Is iOS',
                        MobileDetectionService.isIOS,
                      ),
                      _buildStatusRow(
                        context,
                        'Is Android',
                        MobileDetectionService.isAndroid,
                      ),
                      _buildStatusRow(
                        context,
                        'Running as PWA',
                        MobileDetectionService.isRunningAsPWA,
                      ),
                      _buildStatusRow(
                        context,
                        'Running in Browser',
                        MobileDetectionService.isRunningInBrowser,
                      ),
                      const Divider(height: 24),
                      if (kIsWeb)
                        _buildStatusRow(
                          context,
                          'PWA Install Prompt Should Show',
                          PwaInstallService().shouldShowPrompt,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value
                ? Colors.green
                : Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _formatValue(String key, dynamic value) {
    // Format timestamps
    if (key.contains('Timestamp') && value != null && value is int) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(value);
        return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(date)} (${_formatDuration(DateTime.now().difference(date))} ago)';
      } catch (e) {
        return value.toString();
      }
    }
    
    // Format durations
    if (key.contains('Time') && value != null && value is int) {
      return '${value}s';
    }
    
    // Format booleans
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    
    // Format null
    if (value == null) {
      return 'null';
    }
    
    return value.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Widget _buildDiagnosticTip(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
