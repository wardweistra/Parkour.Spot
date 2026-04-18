import 'package:flutter/material.dart';

class SnackbarService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    final state = messengerKey.currentState;
    if (state == null) return;
    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  static void showError(String message) {
    final state = messengerKey.currentState;
    if (state == null) return;
    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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


