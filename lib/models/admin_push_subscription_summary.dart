/// One row from [listPushSubscriptionsForAdmin] (no full FCM token).
class AdminPushSubscriptionSummary {
  const AdminPushSubscriptionSummary({
    required this.id,
    required this.installationId,
    required this.enabled,
    this.platform,
    this.permission,
    this.tokenSuffix,
    this.userAgent,
    this.isMobileDevice = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.isRunningAsPWA = false,
    this.isRunningInBrowser = false,
    this.updatedAtMillis,
    this.lastSeenAtMillis,
  });

  final String id;
  final String installationId;
  final bool enabled;
  final String? platform;
  final String? permission;
  final String? tokenSuffix;
  final String? userAgent;
  final bool isMobileDevice;
  final bool isAndroid;
  final bool isIOS;
  final bool isRunningAsPWA;
  final bool isRunningInBrowser;
  final int? updatedAtMillis;
  final int? lastSeenAtMillis;

  factory AdminPushSubscriptionSummary.fromCallableMap(Map<String, dynamic> m) {
    final id = m['id'] as String? ?? '';
    return AdminPushSubscriptionSummary(
      id: id,
      installationId: m['installationId'] as String? ?? id,
      enabled: m['enabled'] == true,
      platform: m['platform'] as String?,
      permission: m['permission'] as String?,
      tokenSuffix: m['tokenSuffix'] as String?,
      userAgent: m['userAgent'] as String?,
      isMobileDevice: m['isMobileDevice'] == true,
      isAndroid: m['isAndroid'] == true,
      isIOS: m['isIOS'] == true,
      isRunningAsPWA: m['isRunningAsPWA'] == true,
      isRunningInBrowser: m['isRunningInBrowser'] == true,
      updatedAtMillis: (m['updatedAtMillis'] as num?)?.toInt(),
      lastSeenAtMillis: (m['lastSeenAtMillis'] as num?)?.toInt(),
    );
  }
}
