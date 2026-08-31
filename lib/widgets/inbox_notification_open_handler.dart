import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../services/user_notification_service.dart';
import '../utils/inbox_notification_open_uri.dart';

/// Marks the matching inbox item read when a push click URL includes `nid`.
///
/// Waits for auth on cold start. Strips `nid` after a signed-in attempt so a
/// failed write does not retry forever. Does nothing when the user is signed
/// out (the param stays until they sign in).
class InboxNotificationOpenHandler extends StatefulWidget {
  const InboxNotificationOpenHandler({super.key, required this.child});

  final Widget child;

  @override
  State<InboxNotificationOpenHandler> createState() =>
      _InboxNotificationOpenHandlerState();
}

class _InboxNotificationOpenHandlerState
    extends State<InboxNotificationOpenHandler> {
  late final GoRouter _router;
  AuthService? _auth;
  bool _consumeScheduled = false;
  String? _inFlightNid;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router;
    _router.routerDelegate.addListener(_scheduleConsume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleConsume());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_scheduleConsume);
      _auth = auth;
      _auth!.addListener(_scheduleConsume);
    }
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_scheduleConsume);
    _auth?.removeListener(_scheduleConsume);
    super.dispose();
  }

  void _scheduleConsume() {
    if (_consumeScheduled) return;
    _consumeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeScheduled = false;
      unawaited(_consumeNid());
    });
  }

  Future<void> _consumeNid() async {
    if (!mounted) return;

    final Uri uri;
    try {
      uri = _router.routerDelegate.currentConfiguration.uri;
    } catch (e, st) {
      debugPrint('InboxNotificationOpenHandler uri: $e\n$st');
      return;
    }

    final nid = notificationIdFromUri(uri);
    if (nid == null) return;
    if (_inFlightNid == nid) return;

    final uid =
        _auth?.currentUser?.uid ?? context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    _inFlightNid = nid;
    try {
      await context.read<UserNotificationService>().markAsRead(nid);
      if (!mounted) return;
      Uri current;
      try {
        current = _router.routerDelegate.currentConfiguration.uri;
      } catch (_) {
        return;
      }
      if (notificationIdFromUri(current) != nid) return;
      _router.replace(goLocationFromUri(current));
    } catch (e, st) {
      debugPrint('InboxNotificationOpenHandler markAsRead: $e\n$st');
    } finally {
      if (_inFlightNid == nid) {
        _inFlightNid = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
