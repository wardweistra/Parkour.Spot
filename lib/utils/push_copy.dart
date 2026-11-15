import 'package:flutter/foundation.dart' show kIsWeb;

import '../l10n/app_localizations.dart';

/// Push notification wording that depends on where the app runs: the web app
/// subscribes "this browser", the native apps subscribe "this device".
class PushCopy {
  PushCopy(this._l10n, {bool? isWeb}) : _isWeb = isWeb ?? kIsWeb;

  final AppLocalizations _l10n;
  final bool _isWeb;

  String get promptListTitle => _isWeb
      ? _l10n.notificationsPushPromptListTitle
      : _l10n.notificationsPushPromptListTitleDevice;

  String get promptTurnOnEmpty => _isWeb
      ? _l10n.notificationsPushPromptTurnOnEmpty
      : _l10n.notificationsPushPromptTurnOnEmptyDevice;

  String get promptBlockedTitle => _isWeb
      ? _l10n.notificationsPushPromptBlockedTitle
      : _l10n.notificationsPushPromptBlockedTitleDevice;

  String get promptBlockedBody => _isWeb
      ? _l10n.notificationsPushPromptBlockedBody
      : _l10n.notificationsPushPromptBlockedBodyDevice;

  String get promptEnabledSnackbar => _isWeb
      ? _l10n.notificationsPushPromptEnabledSnackbar
      : _l10n.notificationsPushPromptEnabledSnackbarDevice;

  String get thisDeviceGroupHelper => _isWeb
      ? _l10n.profileNotificationSettingsThisDeviceGroupHelper
      : _l10n.profileNotificationSettingsThisDeviceGroupHelperDevice;

  String get unsupported => _isWeb
      ? _l10n.profilePushNotificationsUnsupported
      : _l10n.profilePushNotificationsUnsupportedDevice;

  String get permissionDenied => _isWeb
      ? _l10n.profilePushNotificationsPermissionDenied
      : _l10n.profilePushNotificationsPermissionDeniedDevice;

  String get permissionNotDetermined => _isWeb
      ? _l10n.profilePushNotificationsPermissionNotDetermined
      : _l10n.profilePushNotificationsPermissionNotDeterminedDevice;

  String get enabled => _isWeb
      ? _l10n.profilePushNotificationsEnabled
      : _l10n.profilePushNotificationsEnabledDevice;

  String get permissionGrantedButOff => _isWeb
      ? _l10n.profilePushNotificationsPermissionGrantedButOff
      : _l10n.profilePushNotificationsPermissionGrantedButOffDevice;

  String get error => _isWeb
      ? _l10n.profilePushNotificationsError
      : _l10n.profilePushNotificationsErrorDevice;

  String get disableMessage => _isWeb
      ? _l10n.profilePushNotificationsDisableMessage
      : _l10n.profilePushNotificationsDisableMessageDevice;
}
