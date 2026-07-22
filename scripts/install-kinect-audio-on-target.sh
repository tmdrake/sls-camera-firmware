#!/usr/bin/env bash
# Run ON the tablet (or: scp debs+UAC then this). Needs root.
# Prefers offline files next to the script or under firmware tree.
set -euo pipefail
if [[ "$(id -u)" -ne 0 ]]; then exec sudo "$0" "$@"; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEB="${1:-}"
UAC="${2:-}"
if [[ -z "$DEB" ]]; then
  DEB=$(ls "$ROOT"/vendor/debs/kinect-audio-setup_*.deb 2>/dev/null | head -1 || true)
fi
if [[ -z "$UAC" ]]; then
  UAC="$ROOT/vendor/kinect/UACFirmware"
fi
export DEBIAN_FRONTEND=noninteractive
# Avoid hang on MS Kinect EULA ncurses prompt (SSH/remote install)
if command -v debconf-set-selections >/dev/null 2>&1; then
  echo 'kinect-audio-setup kinect-audio-setup/accept_eula boolean true' | debconf-set-selections 2>/dev/null || true
  echo 'kinect-audio-setup kinect-audio-setup/accepted-kinect-eula boolean true' | debconf-set-selections 2>/dev/null || true
fi
if [[ -n "$DEB" && -f "$DEB" ]]; then
  echo "Installing $DEB"
  apt-get install -y "$DEB" || dpkg -i "$DEB" || true
  apt-get install -f -y || true
else
  echo "No local deb — apt install kinect-audio-setup (needs network)"
  apt-get update || true
  apt-get install -y --no-install-recommends kinect-audio-setup wget 7zip || true
fi
if [[ -f "$UAC" ]]; then
  mkdir -p /lib/firmware/kinect
  install -m 644 "$UAC" /lib/firmware/kinect/UACFirmware
  echo "Installed UAC firmware → /lib/firmware/kinect/UACFirmware"
else
  echo "WARN: no UACFirmware at $UAC — mic may stay missing until firmware loads"
fi
dpkg --configure -a || true
udevadm control --reload-rules || true
echo
echo "Unplug and replug Kinect USB (power brick on), then:"
echo "  arecord -l"
echo "Restart SLS app — spectrum should not say only 'default'"
