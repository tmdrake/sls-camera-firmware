#!/usr/bin/env bash
# Sync sls-camera application into build/app (and optional vendor/sls-camera).
#
# Env:
#   APP_SRC   — local path to existing clone (e.g. ~/sls-camera)
#   APP_URL   — git remote (default: https://github.com/tmdrake/sls-camera.git)
#   APP_REF   — commit/tag/branch (default: packages/app-ref.txt)
#   COPY_TO_VENDOR=1 — also rsync into vendor/sls-camera
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_URL="${APP_URL:-https://github.com/tmdrake/sls-camera.git}"
if [[ -z "${APP_REF:-}" ]]; then
  APP_REF="$(grep -vE '^\s*(#|$)' packages/app-ref.txt | head -1 | tr -d '[:space:]')"
fi
APP_REF="${APP_REF:-main}"
DEST="$ROOT/build/app"

echo "=== Sync sls-camera ==="
echo "  REF=$APP_REF"
mkdir -p "$ROOT/build"

if [[ -n "${APP_SRC:-}" && -d "${APP_SRC}/.git" ]]; then
  echo "  Using local APP_SRC=$APP_SRC"
  rm -rf "$DEST"
  mkdir -p "$DEST"
  # Copy working tree (no .git to keep appliance slim) unless KEEP_GIT=1
  if [[ "${KEEP_GIT:-0}" == "1" ]]; then
    git clone --no-checkout "$APP_SRC" "$DEST"
    git -C "$DEST" checkout "$APP_REF" 2>/dev/null || git -C "$DEST" checkout -f
  else
    rsync -a --delete \
      --exclude '.git' \
      --exclude 'software/linux/viewer/.venv' \
      --exclude 'software/linux/viewer/captures' \
      --exclude '**/__pycache__' \
      --exclude '**/*.pyc' \
      "$APP_SRC/" "$DEST/"
  fi
else
  echo "  Cloning $APP_URL"
  if [[ -d "$DEST/.git" ]]; then
    git -C "$DEST" fetch --tags origin
    git -C "$DEST" checkout "$APP_REF"
    git -C "$DEST" pull --ff-only 2>/dev/null || true
  else
    rm -rf "$DEST"
    git clone "$APP_URL" "$DEST"
    git -C "$DEST" checkout "$APP_REF"
  fi
fi

# Record what we synced
{
  echo "# Synced $(date -Iseconds 2>/dev/null || date)"
  if [[ -d "$DEST/.git" ]]; then
    git -C "$DEST" rev-parse HEAD
  else
    echo "$APP_REF (rsync from APP_SRC)"
  fi
} > "$ROOT/build/app-synced-ref.txt"

if [[ "${COPY_TO_VENDOR:-0}" == "1" ]]; then
  echo "  COPY_TO_VENDOR=1 → vendor/sls-camera"
  mkdir -p "$ROOT/vendor/sls-camera"
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'software/linux/viewer/.venv' \
    --exclude 'software/linux/viewer/captures' \
    "$DEST/" "$ROOT/vendor/sls-camera/"
fi

echo "App at: $DEST"
if [[ -f "$DEST/software/linux/viewer/run.sh" ]]; then
  echo "OK: viewer/run.sh present"
else
  echo "ERROR: viewer/run.sh missing — wrong tree?" >&2
  exit 1
fi
