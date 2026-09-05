#!/usr/bin/env bash
# Point this clone at the shared .githooks/ directory (committed with the repo).
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${repo_root}"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

echo "Git hooks enabled (core.hooksPath=.githooks)."
echo "Pre-commit will run: cd functions && npm run lint when functions/ files are staged."
