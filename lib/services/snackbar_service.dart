import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SnackbarService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    final state = messengerKey.currentState;
    if (state == null) return;
    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  static void showError(String message) {
    final state = messengerKey.currentState;
    if (state == null) return;
    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Foreground FCM on web: system notification may not appear; show in-app.
  ///
  /// When [onOpenLink] is set (e.g. FCM `data.openUrl`), **Open** follows the
  /// push URL. Dismiss (×) stays trailing.
  static void showFcmForeground(
    String title,
    String? body, {
    VoidCallback? onOpenLink,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = messengerKey.currentState;
      final overlayContext = messengerKey.currentContext;
      if (messenger == null || overlayContext == null) return;
      messenger.clearSnackBars();

      final theme = Theme.of(overlayContext);
      final l10n = AppLocalizations.of(overlayContext);
      final onInverse = theme.colorScheme.onInverseSurface;
      final bodyTrimmed = body?.trim();
      final hasBody = bodyTrimmed != null && bodyTrimmed.isNotEmpty;

      final textColumn = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                theme.textTheme.titleSmall?.copyWith(
                  color: onInverse,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  letterSpacing: 0.1,
                ) ??
                TextStyle(
                  color: onInverse,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.25,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasBody) ...[
            const SizedBox(height: 6),
            Text(
              bodyTrimmed,
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: onInverse.withValues(alpha: 0.88),
                    height: 1.35,
                  ) ??
                  TextStyle(
                    color: onInverse.withValues(alpha: 0.88),
                    fontSize: 14,
                    height: 1.35,
                  ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );

      final closeTooltip = MaterialLocalizations.of(
        overlayContext,
      ).closeButtonTooltip;
      final accent = theme.colorScheme.inversePrimary;
      final textActionStyle = TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(48, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onOpenLink != null) ...[
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onOpenLink();
              },
              style: textActionStyle,
              child: Text(l10n?.notificationPushOpen ?? 'Open'),
            ),
            const SizedBox(width: 12),
          ],
          Tooltip(
            message: closeTooltip,
            child: IconButton(
              onPressed: () => messenger.hideCurrentSnackBar(),
              icon: Icon(Icons.close, color: onInverse.withValues(alpha: 0.92)),
              style: IconButton.styleFrom(
                foregroundColor: onInverse,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      );

      final content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: textColumn),
          const SizedBox(width: 16),
          actions,
        ],
      );

      messenger.showSnackBar(
        SnackBar(
          content: content,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 14),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ),
      );
    });
  }

  /// Clipboard confirmation (uses [messengerKey] so it shows on web reliably).
  ///
  /// Schedules on the next frame so it still appears after `await Clipboard.setData`
  /// on web, when the scaffold messenger can miss immediate updates.
  static void showClipboardCopied(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = messengerKey.currentState;
      if (state == null) return;
      state.clearSnackBars();
      state.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    });
  }
}
