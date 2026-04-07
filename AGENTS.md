# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Parkour Spot is a Flutter web PWA with a Firebase backend (Cloud Functions in `functions/`). See `README.md` for full details.

### Prerequisites

- **Flutter 3.35.0** installed at `/opt/flutter` (added to PATH via `~/.bashrc`)
- **Node.js 22** (pre-installed via nvm)
- **Java 21** (pre-installed; required for Firebase emulators)
- **Firebase CLI** (`npm install -g firebase-tools`)

### Running services for local development

Two tmux sessions are needed:

1. **Firebase Emulators** (Auth :9099, Firestore :8082, Storage :9199, Functions :5001, UI :4000):
   ```
   firebase emulators:start --only auth,firestore,storage,functions \
     --export-on-exit=".firebase/emulator-data" --import=".firebase/emulator-data"
   ```

2. **Flutter Web App** (:8080):
   ```
   flutter run -d web-server --web-port 8080 \
     --dart-define=USE_EMULATOR=true \
     --dart-define=FIREBASE_API_KEY=dummy-api-key-for-emulator \
     --dart-define=FIREBASE_APP_ID_WEB=1:123456789:web:abcdef \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=123456789 \
     --dart-define=FIREBASE_PROJECT_ID=parkourspot-93c90 \
     --dart-define=FIREBASE_AUTH_DOMAIN=localhost \
     --dart-define=FIREBASE_STORAGE_BUCKET=parkourspot-93c90.firebasestorage.app \
     --dart-define=FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX
   ```

Alternatively, use the shell scripts: `./scripts/start_emulators.sh` and `./scripts/run_local_with_emulators.sh` (note: the latter has an interactive `read -p` prompt that must be skipped or piped).

### Non-obvious caveats

- A `.firebaserc` file must exist for the emulators to start. If missing, create one: `echo '{"projects":{"default":"parkourspot-93c90"}}' > .firebaserc`
- Seed data is at `scripts/seed-data/` and must be copied to `.firebase/emulator-data/` before first emulator run. The `start_emulators.sh` script handles this automatically.
- **Seed auth test users** (see README **Seed data reference** for full detail): `user@parkour.spot`, `moderator@parkour.spot`, and `admin@parkour.spot` use email/password with password equal to the email address (regular user, moderator, and admin roles). `google@parkour.spot` is set up for Sign in with Google only (not email/password). For any new accounts you create locally, verify email in the Emulator UI at `http://localhost:4000/auth`.
- `flutter analyze` will show ~119 `info`-level diagnostics (deprecated API usage, `use_build_context_synchronously`). These are not errors and do not block builds or tests.
- The `run_local_with_emulators.sh` script has a `read -p` prompt. For non-interactive use, run the `flutter run` command directly with the dart-defines shown above.
- Cloud Functions lint and tests: `cd functions && npm run lint` and `cd functions && npm test`.
- Flutter tests: `flutter test` from the workspace root.
