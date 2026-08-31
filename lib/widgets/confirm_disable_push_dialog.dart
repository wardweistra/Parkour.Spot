import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Confirm turning off this-browser push. Returns true only if the user agrees.
Future<bool> confirmDisablePushNotifications(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.profilePushNotificationsDisableTitle),
        content: Text(l10n.profilePushNotificationsDisableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profilePushNotificationsDisableConfirm),
          ),
        ],
      );
    },
  );
  return result == true;
}
