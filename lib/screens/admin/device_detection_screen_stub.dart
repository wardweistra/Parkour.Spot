import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Native stub: PWA/device diagnostics are web-only.
class DeviceDetectionScreen extends StatelessWidget {
  const DeviceDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device detection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Device and PWA diagnostics are available in the web admin UI.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
