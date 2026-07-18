#!/usr/bin/env bash
# Download offline debs, Python wheels, and MediaPipe model into vendor/.
# Requires network (or local fallbacks). Run on Ubuntu matching the tablet series.
#
# Sources used (all public / already used by sls-camera):
#   - Ubuntu apt (freenect, PortAudio, …)
#   - PyPI wheels (same packages as software/linux/viewer/requirements.txt)
#   - Google MediaPipe pose model URL (same as viewer run.sh)
#   - Optional local copy: ~/sls-camera/software/linux/viewer/models/*.task
#
# Does NOT download Microsoft Kinect UAC firmware.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEBS="$ROOT/vendor/debs"
WHEELS="$ROOT/vendor/wheels"
MODELS="$ROOT/vendor/models"
mkdir -p "$DEBS" "$WHEELS" "$MODELS"

echo "=== Fetch offline packages ==="
echo "Root: $ROOT"

# --- resolve apt package name if renamed (t64 etc.) ---
resolve_pkg() {
  local p="$1"
  if apt-cache show "$p" >/dev/null 2>&1; then
    echo "$p"
    return 0
  fi
  # common renames
  case "$p" in
    libfreenect0.5)
      if apt-cache show libfreenect0.5t64 >/dev/null 2>&1; then
        echo "libfreenect0.5t64"
        return 0
      fi
      ;;
    libfreenect0.5t64)
      if apt-cache show libfreenect0.5 >/dev/null 2>&1; then
        echo "libfreenect0.5"
        return 0
      fi
      ;;
  esac
  return 1
}

# --- apt debs ---
if command -v apt-get >/dev/null 2>&1; then
  mapfile -t RAW < <(grep -vE '^\s*(#|$)' packages/apt-packages.txt || true)
  PKGS=()
  for p in "${RAW[@]}"; do
    if rp="$(resolve_pkg "$p")"; then
      if [[ "$rp" != "$p" ]]; then
        echo "  resolve: $p → $rp"
      fi
      PKGS+=("$rp")
    else
      echo "  skip (no candidate): $p"
    fi
  done
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    echo "Downloading ${#PKGS[@]} debs into vendor/debs …"
    ok=0
    fail=0
    for p in "${PKGS[@]}"; do
      if (cd "$DEBS" && apt-get download "$p"); then
        ok=$((ok + 1))
      else
        echo "  FAIL deb: $p"
        fail=$((fail + 1))
      fi
    done
    echo "Debs: $ok downloaded, $fail failed, total files=$(find "$DEBS" -name '*.deb' | wc -l)"
  fi
else
  echo "SKIP debs: no apt-get"
fi

# --- python wheels (prefer uv / existing venv; bootstrap pip if needed) ---
REQ="$ROOT/packages/python-requirements.txt"
# Prefer requirements from synced app if present
if [[ -f "$ROOT/build/app/software/linux/viewer/requirements.txt" ]]; then
  REQ="$ROOT/build/app/software/linux/viewer/requirements.txt"
  echo "Using app requirements: $REQ"
fi

download_wheels() {
  local py="$1"
  shift
  echo "  using: $py"
  if "$py" -m pip --version >/dev/null 2>&1; then
    "$py" -m pip download -r "$REQ" -d "$WHEELS" "$@"
    return $?
  fi
  return 1
}

echo "Downloading wheels from $REQ …"
WHEEL_OK=0
export PATH="${HOME}/.local/bin:${PATH}"

if command -v uv >/dev/null 2>&1; then
  echo "  trying uv pip download…"
  if uv pip download -r "$REQ" -d "$WHEELS"; then
    WHEEL_OK=1
  fi
fi

if [[ "$WHEEL_OK" -eq 0 ]] && [[ -x /home/tmdrake/sls-camera/software/linux/viewer/.venv/bin/python ]]; then
  echo "  trying sibling sls-camera venv…"
  if download_wheels /home/tmdrake/sls-camera/software/linux/viewer/.venv/bin/python; then
    WHEEL_OK=1
  fi
fi

if [[ "$WHEEL_OK" -eq 0 ]]; then
  # bootstrap a throwaway venv with ensurepip / get-pip
  BOOT="$ROOT/build/fetch-venv"
  echo "  bootstrapping $BOOT …"
  rm -rf "$BOOT"
  if python3 -m venv "$BOOT" 2>/dev/null; then
    :
  else
    # venv without ensurepip on some minimal images
    python3 -m venv --without-pip "$BOOT" 2>/dev/null || true
  fi
  if [[ -x "$BOOT/bin/python" ]]; then
    if ! "$BOOT/bin/python" -m pip --version >/dev/null 2>&1; then
      echo "  installing pip into bootstrap venv…"
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$ROOT/build/get-pip.py"
      "$BOOT/bin/python" "$ROOT/build/get-pip.py" --force-reinstall
    fi
    if download_wheels "$BOOT/bin/python"; then
      WHEEL_OK=1
    fi
  fi
fi

if [[ "$WHEEL_OK" -eq 0 ]]; then
  echo "WARN: wheel download failed."
  echo "  Fix on build host (pick one):"
  echo "    sudo apt install python3-pip python3-venv"
  echo "    # or: curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "    # or use the sls-camera viewer venv after: cd ~/sls-camera/software/linux/viewer && ./run.sh --help"
else
  echo "Wheels now: $(find "$WHEELS" -type f ! -name '.*' | wc -l) files"
fi

# --- MediaPipe pose model ---
MODEL_URL="https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task"
MODEL_OUT="$MODELS/pose_landmarker_lite.task"
LOCAL_MODEL=""
for cand in \
  /home/tmdrake/sls-camera/software/linux/viewer/models/pose_landmarker_lite.task \
  "$ROOT/build/app/software/linux/viewer/models/pose_landmarker_lite.task"
do
  if [[ -f "$cand" && -s "$cand" ]]; then
    LOCAL_MODEL="$cand"
    break
  fi
done

if [[ -f "$MODEL_OUT" && -s "$MODEL_OUT" ]]; then
  echo "Pose model already present: $MODEL_OUT ($(du -h "$MODEL_OUT" | awk '{print $1}'))"
elif [[ -n "$LOCAL_MODEL" ]]; then
  echo "Copying pose model from local app tree: $LOCAL_MODEL"
  cp -a "$LOCAL_MODEL" "$MODEL_OUT"
  ls -lh "$MODEL_OUT"
else
  echo "Downloading pose model from Google MediaPipe storage…"
  if curl -L --fail -o "$MODEL_OUT" "$MODEL_URL"; then
    ls -lh "$MODEL_OUT"
  else
    echo "WARN: model download failed. Place pose_landmarker_lite.task in vendor/models/"
    rm -f "$MODEL_OUT"
  fi
fi

echo
echo "=== Offline fetch summary ==="
echo "  debs:   $(find "$DEBS" -name '*.deb' 2>/dev/null | wc -l)"
echo "  wheels: $(find "$WHEELS" -type f ! -name '.*' 2>/dev/null | wc -l)"
echo "  model:  $( [[ -s "$MODEL_OUT" ]] && echo OK || echo MISSING )"
echo
echo "Sources: Ubuntu apt + PyPI (app requirements) + MediaPipe model URL"
echo "Not included: Microsoft Kinect UAC firmware (kinect-audio-setup separately)"
