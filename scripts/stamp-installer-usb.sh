#!/usr/bin/env bash
# Put SLS instructions (and optional thin helpers) on the *Lubuntu installer* stick.
#
# A dd/Rufus ISO image is often ISO9660 (read-only). This script needs a
# **writable** mount: Ventoy data partition, free FAT partition, or a remade
# stick that exposes a vfat root you can write.
#
# Usage:
#   sudo ./scripts/stamp-installer-usb.sh /dev/sdX1
#   ./scripts/stamp-installer-usb.sh /run/media/$USER/LUBUNTU
#   ./scripts/stamp-installer-usb.sh /media/$USER/USBSTICK
#
# Does NOT wipe the stick or copy the multi‑GB firmware tree (use
# 50-build-field-usb.sh → SLS-MEDIA for that).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/media/installer-usb"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 </dev/sdXN | /path/to/mount>" >&2
  echo "Tip: lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT,TRAN" >&2
  exit 1
fi

MNT=""
UNMOUNT=0
if [[ -b "$TARGET" ]]; then
  if [[ "$(id -u)" -ne 0 ]]; then
    exec sudo "$0" "$@"
  fi
  MNT="$(mktemp -d /tmp/sls-installer-usb.XXXXXX)"
  if ! mount "$TARGET" "$MNT" 2>/dev/null; then
    rmdir "$MNT"
    echo "ERROR: cannot mount $TARGET (read-only ISO9660 hybrid? use Ventoy or a data partition)" >&2
    exit 1
  fi
  UNMOUNT=1
elif [[ -d "$TARGET" ]]; then
  MNT="$TARGET"
else
  echo "ERROR: not a block device or directory: $TARGET" >&2
  exit 1
fi

cleanup() {
  if [[ "$UNMOUNT" -eq 1 ]]; then
    umount "$MNT" 2>/dev/null || true
    rmdir "$MNT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Writability probe
PROBE="$MNT/.sls-write-test.$$"
if ! touch "$PROBE" 2>/dev/null; then
  echo "ERROR: $MNT is not writable (typical for pure ISO installer images)." >&2
  echo "  Remake with Ventoy, or keep a second stick as SLS-MEDIA." >&2
  echo "  Instructions still live in: $SRC/" >&2
  exit 1
fi
rm -f "$PROBE"

install -m 644 "$SRC/README-SLS-INSTALL.txt" "$MNT/README-SLS-INSTALL.txt"
install -m 644 "$SRC/NEXT-STEPS.txt" "$MNT/NEXT-STEPS.txt"

# Thin helper: after OS install, remind operator (not a full offline pack)
cat >"$MNT/install-sls-after-os.sh" <<'EOF'
#!/usr/bin/env bash
# After Lubuntu is installed to internal storage, run appliance install
# from the SLS-MEDIA field stick (not from this OS installer stick alone).
set -euo pipefail
echo "=== SLS post-OS helper ==="
echo
echo "This installer USB does not contain the offline firmware tree."
echo "Plug the stick labeled SLS-MEDIA, then:"
echo
echo "  cd /media/\$USER/SLS-MEDIA || cd /run/media/\$USER/SLS-MEDIA"
echo "  bash install-from-usb.sh"
echo "  sudo reboot"
echo
# Auto-detect if SLS-MEDIA is already mounted
for d in /media/*/* /run/media/*/*; do
  [[ -f "$d/install-from-usb.sh" && -d "$d/firmware/scripts" ]] || continue
  echo "Found field media at: $d"
  echo "Run:  bash \"$d/install-from-usb.sh\""
  if [[ "${SLS_RUN:-0}" == "1" ]]; then
    exec bash "$d/install-from-usb.sh" "$@"
  fi
  exit 0
done
echo "SLS-MEDIA not mounted yet — insert it and re-run, or set SLS_RUN=1 when present."
exit 1
EOF
chmod +x "$MNT/install-sls-after-os.sh" 2>/dev/null || true

sync
echo "=== Stamped installer USB root ==="
echo "  mount: $MNT"
ls -la "$MNT/README-SLS-INSTALL.txt" "$MNT/NEXT-STEPS.txt" "$MNT/install-sls-after-os.sh"
echo
echo "Open README-SLS-INSTALL.txt on the tablet (live or installed)."
echo "Full offline appliance still requires SLS-MEDIA (50-build-field-usb.sh)."
