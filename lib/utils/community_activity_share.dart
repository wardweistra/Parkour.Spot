import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/snackbar_service.dart';
import '../services/url_service.dart';
import '../services/web_share_service.dart';
import 'share_link_text.dart';

/// URL and display-name context for sharing from the Community dialog (spot detail).
class CommunitySpotShareContext {
  const CommunitySpotShareContext({
    required this.spotId,
    this.spotDisplayName,
    this.countryCode,
    this.city,
  });

  final String spotId;
  final String? spotDisplayName;
  final String? countryCode;
  final String? city;

  String resolveSpotLabel(String? modelSpotName, AppLocalizations l10n) {
    final a = spotDisplayName?.trim();
    if (a != null && a.isNotEmpty) return a;
    final b = modelSpotName?.trim();
    if (b != null && b.isNotEmpty) return b;
    return l10n.communityShareSpotFallbackName;
  }
}

/// Same flow as spot detail / spot card: Web Share on mobile web, else clipboard.
Future<void> shareCommunitySpotMessage(
  BuildContext context, {
  required CommunitySpotShareContext shareContext,
  required String narrativeLine,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final url = UrlService.generateSpotUrl(
      shareContext.spotId,
      countryCode: shareContext.countryCode,
      city: shareContext.city,
    );
    final outcome = await WebShareService.tryShareLink(
      text: ShareLinkText.shareLabel(ShareLinkKind.spot, narrativeLine),
      url: url,
    );
    if (outcome == WebShareOutcome.shared ||
        outcome == WebShareOutcome.cancelled) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: ShareLinkText.clipboardText(
          ShareLinkKind.spot,
          narrativeLine,
          url,
        ),
      ),
    );
    SnackbarService.showClipboardCopied(
      l10n.communityActivityShareCopiedToClipboard,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.communityActivityShareFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
