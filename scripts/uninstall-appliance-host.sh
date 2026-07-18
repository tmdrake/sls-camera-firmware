#!/usr/bin/env bash
# Reverse scripts/install-appliance.sh on a *dev host* (not a field tablet).
#
# Safe: does NOT touch ~/sls-camera or ~/sls-camera-firmware.
# Keeps Kinect udev + gspca blacklist (useful for host development).
#
#   sudo ./scripts/uninstall-appliance-host.sh
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

SLS_USER="${SLS_USER:-sls}"
APP_ROOT="/opt/sls-camera"
DATA_CAPTURES="/data/sls-captures"

echo "=== SLS appliance host cleanup ==="
echo "  Will remove: user $SLS_USER, $APP_ROOT, /data, launcher, LightDM autologin"
echo "  Will KEEP:   udev + gspca blacklist (host Kinect dev)"
echo "  Will KEEP:   $HOME projects under /home/* (except /home/$SLS_USER)"
echo

# LightDM autologin
if [[ -f /etc/lightdm/lightdm.conf.d/50-sls-autologin.conf ]]; then
  rm -f /etc/lightdm/lightdm.conf.d/50-sls-autologin.conf
  echo "Removed LightDM 50-sls-autologin.conf"
fi

# Launcher
if [[ -f /usr/local/bin/sls-camera ]]; then
  rm -f /usr/local/bin/sls-camera
  echo "Removed /usr/local/bin/sls-camera"
fi

# App install tree (copy only — not the git checkout)
if [[ -d "$APP_ROOT" ]]; then
  # Refuse if it looks like a live git worktree of the user's project
  if [[ -d "$APP_ROOT/.git" ]]; then
    echo "REFUSE: $APP_ROOT contains .git — remove manually if intentional" >&2
    exit 1
  fi
  rm -rf "$APP_ROOT"
  echo "Removed $APP_ROOT"
fi

# Captures data dir
if [[ -d "$DATA_CAPTURES" ]]; then
  rm -rf "$DATA_CAPTURES"
  echo "Removed $DATA_CAPTURES"
fi
if [[ -d /data ]] && [[ -z "$(ls -A /data 2>/dev/null || true)" ]]; then
  rmdir /data 2>/dev/null && echo "Removed empty /data" || true
fi

# User + home
if id "$SLS_USER" &>/dev/null; then
  # Kill sessions if any
  pkill -u "$SLS_USER" 2>/dev/null || true
  sleep 0.5
  userdel -r "$SLS_USER" 2>/dev/null || {
    userdel "$SLS_USER" 2>/dev/null || true
    rm -rf "/home/$SLS_USER"
  }
  echo "Removed user $SLS_USER and home"
fi

# Optional: leave group if empty
if getent group "$SLS_USER" &>/dev/null; then
  groupdel "$SLS_USER" 2>/dev/null || true
fi

echo
echo "=== Cleanup complete ==="
echo "Kept (on purpose):"
echo "  /etc/modprobe.d/blacklist-gspca-kinect.conf"
echo "  /etc/udev/rules.d/60-sls-kinect.rules"
echo "  /home/tmdrake/sls-camera*"
echo
echo "Packages installed via dpkg -i (freenect, etc.) were left installed."
echo "They are normal for this dev host."
