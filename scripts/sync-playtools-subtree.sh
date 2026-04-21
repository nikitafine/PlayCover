#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE_NAME="playtools-upstream"
BRANCH_NAME="main"

if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  echo "Missing git remote '$REMOTE_NAME'."
  echo "Add it with:"
  echo "  git remote add $REMOTE_NAME https://github.com/PlayCover/PlayTools.git"
  exit 1
fi

git fetch "$REMOTE_NAME" "$BRANCH_NAME"
git subtree pull --prefix=Vendor/PlayTools "$REMOTE_NAME" "$BRANCH_NAME"
