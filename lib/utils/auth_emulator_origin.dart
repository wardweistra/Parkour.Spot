import 'auth_emulator_origin_stub.dart'
    if (dart.library.js_interop) 'auth_emulator_origin_web.dart' as impl;

/// Pre-registers the Auth emulator origin for the web Auth plugin.
///
/// Call before `Firebase.initializeApp`. On web, the JS Auth instance is
/// created during `initializeApp` and immediately restores the persisted user,
/// including a redirect check against `https://<authDomain>/__/auth/iframe`.
/// When the emulator is only connected afterwards via `useAuthEmulator`, that
/// check fails and the SDK clears the persisted user, so every new tab starts
/// signed out. `firebase_auth_web` connects the emulator at creation time when
/// it finds this origin in sessionStorage (debug builds on `localhost` only).
void preconfigureAuthEmulatorOrigin(String host, int port) =>
    impl.preconfigureAuthEmulatorOrigin(host, port);
