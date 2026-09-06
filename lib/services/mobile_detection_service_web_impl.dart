/// Non-web placeholders (never called when [kIsWeb] is false).
bool isMobileUserAgent() => false;
bool isMobileDevice() => false;
bool isIOS() => false;
bool isAndroid() => false;
bool isRunningAsPWA() => false;
Map<String, dynamic> detailedDeviceInfo() => const {'platform': 'stub'};
