// Web implementation: listens for CustomEvent('password-autofill') from web/index.html
// and forwards values to provided setters.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:async';

class WebPasswordManagerBridge {
  StreamSubscription<html.Event>? _subscription;

  void init({required void Function(String) setEmail, required void Function(String) setPassword}) {
    _subscription = html.window.on['password-autofill'].listen((event) {
      try {
        final customEvent = event as html.CustomEvent;
        final dynamic detail = customEvent.detail;
        if (detail is Map) {
          final username = (detail['username'] ?? '') as String;
          final password = (detail['password'] ?? '') as String;
          if (username.isNotEmpty) {
            setEmail(username);
          }
          if (password.isNotEmpty) {
            setPassword(password);
          }
        }
      } catch (_) {}
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

