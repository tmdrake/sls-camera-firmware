#!/usr/bin/env bash
# Download offline debs, Python wheels, and MediaPipe model into vendor/.
# Requires network. Run on an Ubuntu series matching the target tablet.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEBS="$ROOT/vendor/debs"
WHEELS="$ROOT/vendor/wheels"
MODELS="$ROOT/vendor/models"
mkdir -p "$DEBS" "$WHEELS" "$MODELS"

echo "=== Fetch offline packages ==="

# --- apt debs ---
if command -v apt-get >/dev/null 2>&1; then
  mapfile -t PKGS < <(grep -vE '^\s*(#|$)' packages/apt-packages.txt || true)
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    echo "Downloading ${#PKGS[@]} debs into vendor/debs …"
    # shellcheck disable=SC2086
    (cd "$DEBS" && apt-get download "${PKGS[@]}" 2>/dev/null) || {
      echo "WARN: apt-get download had errors (some packages may be virtual/renamed)."
      echo "      Install missing packages online once, or edit packages/apt-packages.txt"
      # retry one-by-one so partial success remains useful
      for p in "${PKGS[@]}"; do
        (cd "$DEBS" && apt-get download "$p") || echo "  skip: $p"
      done
    }
    echo "Debs now: $(find "$DEBS" -name '*.deb' | wc -l) files"
  fi
else
  echo "SKIP debs: no apt-get"
fi

# --- python wheels ---
REQ="$ROOT/packages/python-requirements.txt"
if command -v python3 >/dev/null 2>&1; then
  echo "Downloading wheels from $REQ …"
  python3 -m pip download -r "$REQ" -d "$WHEELS" \
    || python3 -m pip download -r "$REQ" -d "$WHEELS" --extra-index-url https://pypi.org/simple
  echo "Wheels now: $(find "$WHEELS" -type f | wc -l) files"
else
  echo "SKIP wheels: no python3"
fi

# --- MediaPipe pose model (same URL as sls-camera run.sh) ---
MODEL_URL="https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task"
MODEL_OUT="$MODELS/pose_landmarker_lite.task"
if [[ ! -f "$MODEL_OUT" ]]; then
  echo "Downloading pose model…"
  curl -L --fail -o "$MODEL_OUT" "$MODEL_URL"
else
  echo "Pose model already present: $MODEL_OUT"
fi
ls -lh "$MODEL_OUT"

echo "=== Offline fetch complete ==="
echo "  $DEBS"
echo "  $WHEELS"
echo "  $MODELS"
