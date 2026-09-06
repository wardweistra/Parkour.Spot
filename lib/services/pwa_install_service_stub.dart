import 'dart:async';

import 'package:flutter/foundation.dart';

/// Native stub: PWA install is not applicable.
class PwaInstallService extends ChangeNotifier {
  static PwaInstallService? _instance;

  PwaInstallService._();

  factory PwaInstallService() {
    _instance ??= PwaInstallService._();
    return _instance!;
  }

  final _availabilityController = StreamController<bool>.broadcast();

  Stream<bool> get installPromptAvailability => _availabilityController.stream;

  bool get isInstallPromptAvailable => false;
  bool get isInstalled => false;
  bool get shouldShowPrompt => false;
  bool get isInstallSupported => false;

  Map<String, dynamic> get debugInfo => {
        'chromeInstallButtonAvailable': false,
        'isInstalled': false,
        'isInstallSupported': false,
        'shouldShowPrompt': false,
        'platform': 'native',
      };

  Future<void> initialize() async {}

  Future<void> trackPageView() async {}

  Future<bool> promptInstall() async => false;

  Future<void> dismissPrompt() async {}

  Map<String, String> getIOSInstallInstructions() => const {
        'title': 'Install Parkour·Spot',
        'step1': '',
        'step2': '',
        'step3': '',
        'step4': '',
      };

  Map<String, String> getAndroidInstallInstructions() => const {
        'title': 'Install Parkour·Spot',
        'step1': '',
        'step2': '',
        'step3': '',
        'step4': '',
      };

  @override
  void dispose() {
    _availabilityController.close();
    super.dispose();
  }
}
