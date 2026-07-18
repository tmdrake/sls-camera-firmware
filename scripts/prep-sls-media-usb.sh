#!/usr/bin/env bash
# Wipe a USB stick and format as FAT32 label SLS-MEDIA for field capture tests.
#
# DANGER: destroys all data on the chosen disk. Only use removable USB.
#
# Usage (host, with sudo):
#   ./scripts/prep-sls-media-usb.sh              # auto-pick SanDisk Cruzer / single USB disk
#   ./scripts/prep-sls-media-usb.sh /dev/sda     # explicit device (whole disk, not partition)
#
# Creates: single FAT32 partition, label SLS-MEDIA, folder sls-captures/
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-running with sudo…"
  exec sudo -E "$0" "$@"
fi

pick_usb() {
  local d name tran rm model
  for d in /sys/block/sd*; do
    [[ -e "$d" ]] || continue
    name=$(basename "$d")
    rm=$(cat "$d/removable" 2>/dev/null || echo 0)
    [[ "$rm" == "1" ]] || continue
    # must be USB
    if udevadm info -q property -n "/dev/$name" 2>/dev/null | grep -q '^ID_BUS=usb$'; then
      model=$(cat "$d/device/model" 2>/dev/null | xargs || true)
      echo "/dev/$name|$model"
    fi
  done
}

DEV="${1:-}"
if [[ -z "$DEV" ]]; then
  mapfile -t CANDS < <(pick_usb)
  if [[ ${#CANDS[@]} -eq 0 ]]; then
    echo "ERROR: no removable USB disk found" >&2
    exit 1
  fi
  if [[ ${#CANDS[@]} -gt 1 ]]; then
    echo "Multiple USB disks — pass one explicitly:" >&2
    printf '  %s\n' "${CANDS[@]}" | sed 's/|/  /' >&2
    exit 1
  fi
  DEV="${CANDS[0]%%|*}"
  MODEL="${CANDS[0]#*|}"
else
  MODEL=$(lsblk -d -no MODEL "$DEV" 2>/dev/null | xargs || true)
fi

# Safety rails
[[ -b "$DEV" ]] || { echo "ERROR: not a block device: $DEV" >&2; exit 1; }
[[ "$DEV" != *nvme* ]] || { echo "ERROR: refusing nvme" >&2; exit 1; }
[[ "$DEV" =~ ^/dev/sd[a-z]$ ]] || {
  echo "ERROR: pass whole disk e.g. /dev/sda (not a partition)" >&2
  exit 1
}
RM=$(cat "/sys/block/$(basename "$DEV")/removable" 2>/dev/null || echo 0)
[[ "$RM" == "1" ]] || { echo "ERROR: $DEV is not marked removable" >&2; exit 1; }
udevadm info -q property -n "$DEV" 2>/dev/null | grep -q '^ID_BUS=usb$' \
  || { echo "ERROR: $DEV is not USB" >&2; exit 1; }

SIZE=$(lsblk -d -nb -o SIZE "$DEV")
# refuse > 128G as accidental HDD
if [[ "$SIZE" -gt $((128 * 1024 * 1024 * 1024)) ]]; then
  echo "ERROR: $DEV larger than 128G — refusing (looks like a hard disk)" >&2
  exit 1
fi

echo "=== Will DESTROY all data on ==="
lsblk -o NAME,SIZE,TRAN,RM,MODEL,LABEL,FSTYPE,MOUNTPOINT "$DEV"
echo "  model: $MODEL"
echo

# Unmount all partitions
for p in "$DEV"*; do
  [[ -b "$p" && "$p" != "$DEV" ]] || continue
  umount "$p" 2>/dev/null || true
  udisksctl unmount -b "$p" 2>/dev/null || true
done
sync

echo "Wiping partition table…"
wipefs -a "$DEV" 2>/dev/null || true
sgdisk --zap-all "$DEV" 2>/dev/null || dd if=/dev/zero of="$DEV" bs=1M count=8 status=none
parted -s "$DEV" mklabel msdos
parted -s "$DEV" mkpart primary fat32 1MiB 100%
partprobe "$DEV" 2>/dev/null || true
sync
sleep 1

PART="${DEV}1"
[[ -b "$PART" ]] || { echo "ERROR: $PART not found after partition" >&2; exit 1; }

echo "Formatting FAT32 label=SLS-MEDIA…"
mkfs.vfat -F 32 -n SLS-MEDIA "$PART"
sync

# Mount via udisks if possible (user-visible path)
MOUNT=""
if command -v udisksctl >/dev/null 2>&1; then
  # drop root for udisks user mount is awkward; mount ourselves then
  :
fi
MNT=/mnt/sls-media
mkdir -p "$MNT"
mount "$PART" "$MNT"
mkdir -p "$MNT/sls-captures"
cat >"$MNT/README-SLS.txt" <<EOF
SLS field media stick
=====================
Label: SLS-MEDIA
Formatted: $(date -Iseconds)
Purpose: Auto captures / USB media testing for SLS Camera appliance

Folder sls-captures/ is where the app may write snaps and AVI when
Captures target is Auto and this stick is mounted.

Safe to reformat. Not a Windows installer anymore.
EOF
sync
umount "$MNT" 2>/dev/null || true

# Try user-friendly automount
if command -v udisksctl >/dev/null 2>&1; then
  udisksctl mount -b "$PART" 2>/dev/null || true
fi

echo
echo "=== Done ==="
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT "$DEV"
echo
echo "Plug into tablet or host; app Auto captures should prefer this volume when mounted."
echo "For guest VM: passthrough USB stick with virt-manager or:"
echo "  virsh attach-device … (optional; host test is enough for media path)"
