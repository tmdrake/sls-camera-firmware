#!/usr/bin/env bash
# Phase 1: install SLS Camera as a system appliance on THIS machine.
#
# Requires root. Prefer a dedicated tablet or VM.
#
#   sudo ./scripts/install-appliance.sh
#
# Optional:
#   SLS_USER=sls
#   APP_SRC from prior 20-sync-app (default: build/app or vendor/sls-camera)
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLS_USER="${SLS_USER:-sls}"
APP_ROOT="/opt/sls-camera"
DATA_CAPTURES="/data/sls-captures"
OVERLAY="$ROOT/overlay"

echo "=== SLS appliance install ==="
echo "  firmware tree: $ROOT"
echo "  user: $SLS_USER"
echo "  app:  $APP_ROOT"

# Resolve app source
if [[ -d "$ROOT/build/app/software/linux/viewer" ]]; then
  SRC="$ROOT/build/app"
elif [[ -d "$ROOT/vendor/sls-camera/software/linux/viewer" ]]; then
  SRC="$ROOT/vendor/sls-camera"
elif [[ -d /home/tmdrake/sls-camera/software/linux/viewer ]]; then
  SRC=/home/tmdrake/sls-camera
  echo "  NOTE: using live checkout $SRC"
else
  echo "ERROR: no app tree. Run scripts/20-sync-app.sh first." >&2
  exit 1
fi
echo "  src: $SRC"

# --- user ---
if ! id "$SLS_USER" &>/dev/null; then
  useradd -m -s /bin/bash -G video,plugdev,audio,sudo "$SLS_USER" || \
    useradd -m -s /bin/bash -G video,plugdev,audio "$SLS_USER"
  echo "Created user $SLS_USER"
else
  usermod -aG video,plugdev,audio "$SLS_USER" 2>/dev/null || true
fi

# --- debs ---
if compgen -G "$ROOT/vendor/debs/*.deb" >/dev/null 2>&1; then
  echo "Installing offline debs…"
  dpkg -i "$ROOT"/vendor/debs/*.deb || apt-get -f install -y
else
  echo "No vendor/debs — installing from apt (online)…"
  mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$ROOT/packages/apt-packages.txt" || true)
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    apt-get update
    apt-get install -y "${PKGS[@]}" || true
  fi
fi

# --- gspca blacklist + udev ---
install -D -m 644 "$OVERLAY/etc/modprobe.d/blacklist-gspca-kinect.conf" \
  /etc/modprobe.d/blacklist-gspca-kinect.conf
install -D -m 644 "$OVERLAY/etc/udev/rules.d/60-sls-kinect.rules" \
  /etc/udev/rules.d/60-sls-kinect.rules
udevadm control --reload-rules 2>/dev/null || true
if lsmod 2>/dev/null | grep -q '^gspca_kinect'; then
  modprobe -r gspca_kinect 2>/dev/null || echo "WARN: could not unload gspca_kinect"
fi

# --- app tree ---
echo "Installing app → $APP_ROOT"
mkdir -p "$APP_ROOT"
rsync -a --delete \
  --exclude '.git' \
  --exclude 'software/linux/viewer/.venv' \
  --exclude 'software/linux/viewer/captures' \
  "$SRC/" "$APP_ROOT/"

# pose model offline
VIEWER="$APP_ROOT/software/linux/viewer"
mkdir -p "$VIEWER/models"
if [[ -f "$ROOT/vendor/models/pose_landmarker_lite.task" ]]; then
  install -m 644 "$ROOT/vendor/models/pose_landmarker_lite.task" \
    "$VIEWER/models/pose_landmarker_lite.task"
fi

# venv
echo "Creating venv…"
python3 -m venv "$VIEWER/.venv"
# shellcheck disable=SC1091
source "$VIEWER/.venv/bin/activate"
pip install --upgrade pip
if compgen -G "$ROOT/vendor/wheels/*" >/dev/null 2>&1; then
  pip install --no-index --find-links="$ROOT/vendor/wheels" -r "$VIEWER/requirements.txt" \
    || pip install --no-index --find-links="$ROOT/vendor/wheels" -r "$ROOT/packages/python-requirements.txt"
else
  pip install -r "$VIEWER/requirements.txt"
fi
# ensure extras
pip install 'sounddevice>=0.5' 'imageio-ffmpeg>=0.5' 2>/dev/null || true
deactivate
chown -R "$SLS_USER:$SLS_USER" "$VIEWER/.venv" 2>/dev/null || true

# launcher
install -D -m 755 "$OVERLAY/usr/local/bin/sls-camera" /usr/local/bin/sls-camera

# captures
mkdir -p "$DATA_CAPTURES"
chown -R "$SLS_USER:$SLS_USER" /data 2>/dev/null || chown -R "$SLS_USER:$SLS_USER" "$DATA_CAPTURES"

# autostart for user
USER_HOME="$(getent passwd "$SLS_USER" | cut -d: -f6)"
install -D -m 644 "$OVERLAY/home/sls/.config/autostart/sls-camera.desktop" \
  "$USER_HOME/.config/autostart/sls-camera.desktop"
chown -R "$SLS_USER:$SLS_USER" "$USER_HOME/.config"

# LightDM autologin if present
if [[ -d /etc/lightdm ]]; then
  conf=/etc/lightdm/lightdm.conf.d/50-sls-autologin.conf
  mkdir -p "$(dirname "$conf")"
  cat >"$conf" <<EOF
[Seat:*]
autologin-user=$SLS_USER
autologin-user-timeout=0
EOF
  echo "Configured LightDM autologin for $SLS_USER"
fi

# GDM autologin if present
if [[ -f /etc/gdm3/custom.conf ]]; then
  if ! grep -q "AutomaticLoginEnable" /etc/gdm3/custom.conf 2>/dev/null; then
    echo "NOTE: enable GDM AutomaticLogin for $SLS_USER in /etc/gdm3/custom.conf if needed"
  fi
fi

echo
echo "=== Appliance install complete ==="
echo "  App:      $APP_ROOT"
echo "  Launcher: /usr/local/bin/sls-camera"
echo "  Captures: $DATA_CAPTURES"
echo "  User:     $SLS_USER (autostart enabled)"
echo
echo "Reboot, plug Kinect + power brick, and the SLS app should start."
echo "Optional mic: sudo apt install kinect-audio-setup  (MS firmware — not bundled)"
