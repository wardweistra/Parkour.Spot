# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

Parkour Spot is a Flutter web PWA with a Firebase backend (Cloud Functions in `functions/`). See `README.md` for full details.

### Prerequisites

- **Flutter ≥ 3.38.1** (Dart ≥ 3.10.0) at `/opt/flutter` (added to PATH via `~/.bashrc`). Current `pubspec.lock` cannot resolve on older SDKs (`share_plus` 13.3.0 needs Dart 3.10+). Use current Flutter **stable** (CI and Cloud Agents track that channel).
- **Node.js 22** (pre-installed via nvm)
- **Java 21** (pre-installed; required for Firebase emulators)
- **Firebase CLI** (`npm install -g firebase-tools`)

### Cloud Agent environment

Repo-managed install lives in `.cursor/environment.json`. Each environment Build runs `./scripts/setup_cloud_agent.sh`, which upgrades `/opt/flutter` to current **stable**, then `flutter pub get` and `functions` `npm ci`.

After changing that config, start a Cloud Agent from the branch so Cursor prepares a new Build. A failed Build does not replace the last good environment.

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
- Before committing Functions changes, lint must pass (`cd functions && npm run lint`). A shared git pre-commit hook enforces this when `functions/` files are staged — enable once with `./scripts/setup_git_hooks.sh`.
- Flutter tests: `flutter test` from the workspace root.
