import 'package:web/web.dart' as web;

/// Key used by `firebase_auth_web` (`getOriginName`) for the default app.
const _defaultAppEmulatorOriginKey = '[DEFAULT]-firebaseEmulatorOrigin';

void preconfigureAuthEmulatorOrigin(String host, int port) {
  web.window.sessionStorage
      .setItem(_defaultAppEmulatorOriginKey, 'http://$host:$port');
}
