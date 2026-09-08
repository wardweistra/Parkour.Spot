#!/usr/bin/env bash
# Idempotent Cloud Agent install: Flutter stable (Dart >= 3.10) plus project deps.
# Used by .cursor/environment.json. Safe to re-run on a prepared disk.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/opt/flutter}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${repo_root}"

export PATH="${FLUTTER_DIR}/bin:${PATH}"

ensure_path() {
  local marker="export PATH=\"${FLUTTER_DIR}/bin:\$PATH\""
  for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    if [[ -f "${rc}" ]] && grep -Fq "${FLUTTER_DIR}/bin" "${rc}"; then
      continue
    fi
    if [[ -f "${rc}" ]] || [[ "${rc}" == "${HOME}/.bashrc" ]]; then
      printf '\n%s\n' "${marker}" >> "${rc}"
    fi
  done
}

ensure_writable_flutter() {
  if [[ -d "${FLUTTER_DIR}" && ! -w "${FLUTTER_DIR}" ]]; then
    sudo chown -R "$(id -un):$(id -gn)" "${FLUTTER_DIR}"
  fi
}

install_flutter() {
  echo "Installing Flutter stable into ${FLUTTER_DIR}"
  sudo mkdir -p "$(dirname "${FLUTTER_DIR}")"
  if [[ -e "${FLUTTER_DIR}" ]]; then
    sudo rm -rf "${FLUTTER_DIR}"
  fi
  sudo git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
  sudo chown -R "$(id -un):$(id -gn)" "${FLUTTER_DIR}"
}

upgrade_flutter() {
  echo "Upgrading Flutter at ${FLUTTER_DIR} to current stable"
  git -C "${FLUTTER_DIR}" fetch --depth 1 origin stable
  git -C "${FLUTTER_DIR}" checkout -B stable origin/stable
  # Non-interactive; precache web artifacts used by this repo.
  flutter config --no-analytics >/dev/null
}

if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]] ||
   ! git -C "${FLUTTER_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
  install_flutter
else
  ensure_writable_flutter
  upgrade_flutter
fi

ensure_path
flutter config --no-analytics >/dev/null
flutter precache --web
flutter --version

if ! command -v firebase >/dev/null 2>&1; then
  npm install -g firebase-tools
fi

if [[ ! -f .firebaserc ]]; then
  printf '%s\n' '{"projects":{"default":"parkourspot-93c90"}}' > .firebaserc
fi

flutter pub get
(cd functions && npm ci)

echo "Cloud Agent environment ready."
