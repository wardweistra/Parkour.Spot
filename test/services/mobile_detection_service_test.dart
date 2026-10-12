import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/mobile_detection_service.dart';

void main() {
  group('MobileDetectionService.supportsWebcalSubscribe', () {
    test('is true on iOS and macOS native targets', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(MobileDetectionService.supportsWebcalSubscribe, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(MobileDetectionService.supportsWebcalSubscribe, isTrue);
    });

    test('is false on Android and other non-Apple native targets', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(MobileDetectionService.supportsWebcalSubscribe, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(MobileDetectionService.supportsWebcalSubscribe, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(MobileDetectionService.supportsWebcalSubscribe, isFalse);
    });
  });
}
