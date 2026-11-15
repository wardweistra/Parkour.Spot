import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Gives the Android system back button (and back gesture) the same behavior
/// as a page's own back arrow when the page is the only one on the stack.
///
/// Pages opened from a deep link, a push notification, or `context.go` have
/// nothing underneath them, so system back would close the app. On web the
/// browser's back button covers this; on native [onBack] runs instead, which
/// typically falls back to Explore.
///
/// Pages that were pushed keep the default behavior (pop).
class SystemBackHandler extends StatelessWidget {
  const SystemBackHandler({
    super.key,
    required this.onBack,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onBack;
  final Widget child;

  /// Set false while the page handles back itself (e.g. an unsaved-changes
  /// prompt in its own [PopScope]).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;

    final isRootRoute = ModalRoute.of(context)?.isFirst ?? false;
    final intercept = enabled && isRootRoute;
    return PopScope(
      canPop: !intercept,
      onPopInvokedWithResult: (didPop, _) {
        // Another PopScope on this route may be the one that blocked the pop;
        // only act when this handler did.
        if (didPop || !intercept) return;
        onBack();
      },
      child: child,
    );
  }
}
