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

# Expand seed packages to hard Depends/PreDepends (transitive).
# Uses apt-cache depends --recurse; keeps only real packages (apt-cache show).
expand_apt_deps() {
  local -a seeds=("$@")
  local line name
  if [[ ${#seeds[@]} -eq 0 ]]; then
    return 0
  fi
  # Output format: bare package name on its own line; field lines are indented.
  # Example:
  #   freenect
  #     Depends: libfreenect-bin
  #   libfreenect-bin
  #     Depends: libglut3.12
  {
    printf '%s\n' "${seeds[@]}"
    apt-cache depends --recurse \
      --no-recommends --no-suggests \
      --no-conflicts --no-breaks --no-replaces --no-enhances \
      "${seeds[@]}" 2>/dev/null || true
  } | while IFS= read -r line; do
    # skip indented field lines and empty
    [[ -z "$line" || "$line" != "${line#"${line%%[![:space:]]*}"}" ]] && continue
    # also skip "package" lines that look like "Depends: ..."
    [[ "$line" == *":"* && "$line" != *":amd64" && "$line" != *":i386" ]] && continue
    name="${line%%:*}"
    name="${name// /}"
    [[ -z "$name" ]] && continue
    if apt-cache show "$name" >/dev/null 2>&1; then
      echo "$name"
    fi
  done | sort -u
}

# --- apt debs (seeds + recursive hard deps for true offline dpkg -i) ---
# Set FETCH_DEPS=0 to download only packages/apt-packages.txt seeds (old behavior).
FETCH_DEPS="${FETCH_DEPS:-1}"
# Kinect audio: multiverse package + optional MS UAC blob into vendor/kinect/ (gitignored)
FETCH_KINECT_UAC="${FETCH_KINECT_UAC:-1}"
if command -v apt-get >/dev/null 2>&1; then
  # kinect-audio-setup is in multiverse on Ubuntu
  if [[ -f /etc/apt/sources.list ]] || compgen -G "/etc/apt/sources.list.d/*" >/dev/null; then
    if ! apt-cache show kinect-audio-setup >/dev/null 2>&1; then
      echo "NOTE: kinect-audio-setup not in apt cache — enable multiverse and apt-get update if you need Kinect mic offline"
    fi
  fi
  mapfile -t RAW < <(grep -vE '^\s*(#|$)' packages/apt-packages.txt || true)
  SEEDS=()
  for p in "${RAW[@]}"; do
    if rp="$(resolve_pkg "$p")"; then
      if [[ "$rp" != "$p" ]]; then
        echo "  resolve: $p → $rp"
      fi
      SEEDS+=("$rp")
    else
      echo "  skip (no candidate): $p"
    fi
  done
  PKGS=("${SEEDS[@]}")
  if [[ "$FETCH_DEPS" != "0" && ${#SEEDS[@]} -gt 0 ]]; then
    echo "Expanding hard dependencies for ${#SEEDS[@]} seed packages…"
    mapfile -t PKGS < <(expand_apt_deps "${SEEDS[@]}")
    echo "  → ${#PKGS[@]} before conflict filter"
    # apt-cache --recurse includes BOTH sides of OR alternatives (e.g. libjack0 |
    # libjack-jackd2-0, libavcodec vs libavcodec-extra). Drop the losers so a
    # blanket dpkg -i vendor/debs/*.deb does not conflict.
    mapfile -t PKGS < <(
      printf '%s\n' "${PKGS[@]}" | grep -Ev \
        '^(libavcodec-extra|libavfilter-extra|libavformat-extra|libavutil-extra)' \
        | grep -Ev '^libjack0$' \
        | grep -Ev -- '-extra[0-9]*$' \
        || true
    )
    echo "  → ${#PKGS[@]} after dropping OR-conflict alternatives"
  fi
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    echo "Downloading ${#PKGS[@]} debs into vendor/debs …"
    ok=0
    fail=0
    # Batch download (apt-get download accepts many names)
    # Split into chunks to avoid argv limits
    chunk=()
    flush_chunk() {
      if [[ ${#chunk[@]} -eq 0 ]]; then
        return 0
      fi
      if (cd "$DEBS" && apt-get download "${chunk[@]}"); then
        ok=$((ok + ${#chunk[@]}))
      else
        # fall back one-by-one so one missing name does not abort the rest
        for p in "${chunk[@]}"; do
          if (cd "$DEBS" && apt-get download "$p"); then
            ok=$((ok + 1))
          else
            echo "  FAIL deb: $p"
            fail=$((fail + 1))
          fi
        done
      fi
      chunk=()
    }
    for p in "${PKGS[@]}"; do
      chunk+=("$p")
      if [[ ${#chunk[@]} -ge 40 ]]; then
        flush_chunk
      fi
    done
    flush_chunk
    # Drop any leftover conflict debs from older fetches
    (cd "$DEBS" && rm -f \
      libavcodec-extra*.deb libavfilter-extra*.deb libavformat-extra*.deb \
      libavutil-extra*.deb libjack0_*.deb 2>/dev/null || true)
    # Persist expanded name list for audit / re-fetch
    printf '%s\n' "${PKGS[@]}" >"$ROOT/vendor/debs/PACKAGE-LIST.txt"
    # Packages index for install-appliance local apt pool (file://vendor/debs)
    if command -v dpkg-scanpackages >/dev/null 2>&1; then
      echo "Writing vendor/debs/Packages index…"
      (cd "$DEBS" && dpkg-scanpackages . /dev/null >Packages) || true
      gzip -kf "$DEBS/Packages" 2>/dev/null || true
    else
      echo "NOTE: install dpkg-dev for dpkg-scanpackages (better offline apt index)."
      echo "  Generating Packages with dpkg-deb fields…"
      : >"$DEBS/Packages"
      for deb in "$DEBS"/*.deb; do
        {
          echo "Package: $(dpkg-deb -f "$deb" Package)"
          echo "Version: $(dpkg-deb -f "$deb" Version)"
          echo "Architecture: $(dpkg-deb -f "$deb" Architecture)"
          dep=$(dpkg-deb -f "$deb" Depends || true)
          [[ -n "$dep" ]] && echo "Depends: $dep"
          pre=$(dpkg-deb -f "$deb" Pre-Depends || true)
          [[ -n "$pre" ]] && echo "Pre-Depends: $pre"
          prov=$(dpkg-deb -f "$deb" Provides || true)
          [[ -n "$prov" ]] && echo "Provides: $prov"
          conf=$(dpkg-deb -f "$deb" Conflicts || true)
          [[ -n "$conf" ]] && echo "Conflicts: $conf"
          rep=$(dpkg-deb -f "$deb" Replaces || true)
          [[ -n "$rep" ]] && echo "Replaces: $rep"
          echo "Filename: ./$(basename "$deb")"
          echo "Size: $(stat -c%s "$deb")"
          echo "MD5sum: $(md5sum "$deb" | awk '{print $1}')"
          echo "SHA256: $(sha256sum "$deb" | awk '{print $1}')"
          echo
        } >>"$DEBS/Packages"
      done
      gzip -kf "$DEBS/Packages" 2>/dev/null || true
    fi
    echo "Debs: ok≈$ok fail=$fail files=$(find "$DEBS" -name '*.deb' | wc -l)"
    echo "  list: vendor/debs/PACKAGE-LIST.txt"
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

# --- Kinect UAC firmware (optional offline complete pack; NOT for public git) ---
KINECT_DIR="$ROOT/vendor/kinect"
mkdir -p "$KINECT_DIR"
if [[ "$FETCH_KINECT_UAC" == "1" ]]; then
  echo
  echo "=== Kinect UAC audio firmware (private offline drop) ==="
  if [[ -f "$KINECT_DIR/UACFirmware" ]]; then
    echo "  already present: $KINECT_DIR/UACFirmware"
  else
    echo "  Fetching MS Kinect SDK Beta2 MSI (license: Microsoft) → extract UACFirmware…"
    TMP=$(mktemp -d)
    (
      set +e
      cd "$TMP"
      URL="http://download.microsoft.com/download/F/9/9/F99791F2-D5BE-478A-B77A-830AD14950C3/KinectSDK-v1.0-beta2-x86.msi"
      if command -v wget >/dev/null 2>&1; then
        wget -q -O KinectSDK-v1.0-beta2-x86.msi "$URL"
      elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o KinectSDK-v1.0-beta2-x86.msi "$URL"
      fi
      if [[ ! -f KinectSDK-v1.0-beta2-x86.msi ]]; then
        echo "  WARN: MSI download failed — offline Kinect mic needs manual vendor/kinect/UACFirmware"
        exit 0
      fi
      md5sum KinectSDK-v1.0-beta2-x86.msi | tee "$KINECT_DIR/KinectSDK-v1.0-beta2-x86.msi.md5"
      if command -v 7z >/dev/null 2>&1; then
        7z e -y -r KinectSDK-v1.0-beta2-x86.msi "UACFirmware.*" >/dev/null
      elif command -v 7za >/dev/null 2>&1; then
        7za e -y -r KinectSDK-v1.0-beta2-x86.msi "UACFirmware.*" >/dev/null
      else
        echo "  WARN: install 7zip to extract UACFirmware (apt install 7zip)"
        exit 0
      fi
      blob=$(ls UACFirmware* 2>/dev/null | head -1)
      if [[ -n "$blob" ]]; then
        cp -a "$blob" "$KINECT_DIR/UACFirmware"
        chmod 644 "$KINECT_DIR/UACFirmware"
        echo "  wrote $KINECT_DIR/UACFirmware (gitignored — private field packs only)"
      else
        echo "  WARN: no UACFirmware* in MSI — list with: 7z l KinectSDK-….msi"
      fi
    )
    rm -rf "$TMP"
  fi
else
  echo "FETCH_KINECT_UAC=0 — skipping MS UAC firmware (Kinect mic needs network on tablet or private drop)"
fi

echo
echo "=== Offline fetch summary ==="
echo "  debs:   $(find "$DEBS" -name '*.deb' 2>/dev/null | wc -l)"
echo "  wheels: $(find "$WHEELS" -type f ! -name '.*' 2>/dev/null | wc -l)"
echo "  model:  $( [[ -s "$MODEL_OUT" ]] && echo OK || echo MISSING )"
echo "  kinect UAC: $( [[ -f "$KINECT_DIR/UACFirmware" ]] && echo OK || echo missing )"
echo
echo "Sources: Ubuntu apt (incl. freenect + kinect-audio-setup deb) + PyPI + pose model"
echo "MS UAC firmware: vendor/kinect/ only (gitignored). Do not commit."
