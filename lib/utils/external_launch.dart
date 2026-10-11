import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Opens [uri] externally; shows a SnackBar if the launch fails.
Future<bool> launchExternalUri(
  BuildContext context,
  Uri uri, {
  String? errorMessage,
}) async {
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLaunchError(context, errorMessage);
      return false;
    }
    return launched;
  } catch (_) {
    if (context.mounted) {
      _showLaunchError(context, errorMessage);
    }
    return false;
  }
}

void _showLaunchError(BuildContext context, String? errorMessage) {
  final message =
      errorMessage ??
      AppLocalizations.of(context)?.profileCouldNotOpenLink ??
      'Could not open link';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
