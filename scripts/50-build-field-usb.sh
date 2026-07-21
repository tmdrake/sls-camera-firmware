#!/usr/bin/env bash
# Populate an SLS-MEDIA (or any mounted FAT) stick with the offline firmware tree
# for Stage A blow-and-go (install-appliance after stock Lubuntu).
#
# Usage (host):
#   sudo ./scripts/50-build-field-usb.sh /dev/sda1
#   sudo ./scripts/50-build-field-usb.sh /run/media/$USER/SLS-MEDIA
#   sudo ISO=/path/to/lubuntu-26.04-desktop-amd64.iso ./scripts/50-build-field-usb.sh /dev/sda1
#
# Prerequisites: 10-fetch-offline.sh + 20-sync-app.sh already run on this host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
ISO_SRC="${ISO:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <mountpoint|/dev/sdXN>" >&2
  echo "  Example: $0 /dev/sda1" >&2
  echo "  Example: $0 /run/media/\$USER/SLS-MEDIA" >&2
  exit 1
fi

# Resolve mountpoint
MNT=""
UNMOUNT_WHEN_DONE=0
if [[ -d "$TARGET" ]]; then
  MNT="$TARGET"
  # User-mounted FAT (udisks) is writable without root — only elevate for raw block devices
elif [[ -b "$TARGET" ]]; then
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Re-running with sudo (block device)…"
    exec sudo -E env ISO="${ISO_SRC}" "$0" "$@"
  fi
  # safety: refuse nvme
  [[ "$TARGET" != *nvme* ]] || { echo "REFUSE nvme" >&2; exit 1; }
  udisksctl unmount -b "$TARGET" 2>/dev/null || umount "$TARGET" 2>/dev/null || true
  MNT="/mnt/sls-field-usb"
  mkdir -p "$MNT"
  mount "$TARGET" "$MNT"
  UNMOUNT_WHEN_DONE=1
else
  echo "ERROR: not a directory or block device: $TARGET" >&2
  exit 1
fi
if [[ ! -w "$MNT" ]]; then
  echo "ERROR: mount not writable: $MNT (remount or use sudo on the block device)" >&2
  exit 1
fi

echo "=== Field USB build ==="
echo "  repo:   $ROOT"
echo "  target: $MNT"

# Prerequisites
if ! compgen -G "$ROOT/vendor/debs/*.deb" >/dev/null; then
  echo "ERROR: vendor/debs empty — run ./scripts/10-fetch-offline.sh first" >&2
  exit 1
fi
if [[ ! -f "$ROOT/build/app/software/linux/viewer/run.sh" ]]; then
  echo "ERROR: build/app missing — run ./scripts/20-sync-app.sh first" >&2
  exit 1
fi

# Space check (rough)
NEED_MB=1200
if [[ -n "$ISO_SRC" && -f "$ISO_SRC" ]]; then
  ISO_MB=$(( $(stat -c%s "$ISO_SRC") / 1024 / 1024 + 100 ))
  NEED_MB=$((NEED_MB + ISO_MB))
fi
AVAIL_KB=$(df -Pk "$MNT" | awk 'NR==2{print $4}')
AVAIL_MB=$((AVAIL_KB / 1024))
echo "  free:   ${AVAIL_MB} MiB (need ~${NEED_MB} MiB)"
if [[ "$AVAIL_MB" -lt "$NEED_MB" ]]; then
  echo "ERROR: not enough free space on $MNT" >&2
  exit 1
fi

# Clean previous payload (keep sls-captures)
rm -rf "$MNT/firmware" "$MNT/optional" "$MNT/install-from-usb.sh" "$MNT/BOOTSTRAP.md" \
  "$MNT/README-SLS.txt" "$MNT/SSH-LAB.txt"
mkdir -p "$MNT/firmware" "$MNT/optional" "$MNT/sls-captures"

echo "Copying firmware tree (excludes .git, large build caches)…"
# FAT32 cannot store Unix owners/permissions — no-owner/no-group and force modes
rsync -rltD --delete \
  --no-owner --no-group --no-perms --chmod=ugo=rwX \
  --exclude '.git/' \
  --exclude 'build/fetch-venv/' \
  --exclude 'build/get-pip.py' \
  --exclude 'out/' \
  --exclude 'docs/images/*.ppm' \
  --exclude '.grok/' \
  "$ROOT/" "$MNT/firmware/"
# Scripts must be executable when copied to ext4 later; on FAT, install-from-usb uses bash
find "$MNT/firmware/scripts" -type f -name '*.sh' -exec chmod 755 {} \; 2>/dev/null || true

# Refresh PACKAGE-LIST if present
if [[ -f "$MNT/firmware/vendor/debs/PACKAGE-LIST.txt" ]]; then
  echo "  debs: $(find "$MNT/firmware/vendor/debs" -name '*.deb' | wc -l)"
fi
echo "  wheels: $(find "$MNT/firmware/vendor/wheels" -type f 2>/dev/null | wc -l)"
echo "  app: $(cat "$MNT/firmware/packages/app-ref.txt" 2>/dev/null | grep -v '^#' | head -1)"

# Install-from-USB helper (runs ON the target machine)
cat >"$MNT/install-from-usb.sh" <<'INSTALL'
#!/usr/bin/env bash
# Run this ON the tablet/VM after Lubuntu 26.04 is installed.
# Mount this stick, then:
#   bash /media/$USER/SLS-MEDIA/install-from-usb.sh
#
# Note: FAT32 may not preserve +x; always invoke with bash.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FW="$HERE/firmware"
INST="$FW/scripts/install-appliance.sh"
if [[ ! -f "$INST" ]]; then
  echo "ERROR: firmware tree missing at $FW (no install-appliance.sh)" >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Need root — re-running with sudo…"
  exec sudo env "HERE=$HERE" bash "$0" "$@"
fi

echo "=== SLS appliance install from field USB ==="
echo "  firmware: $FW"
cd "$FW"
bash ./scripts/install-appliance.sh

# Lab password (same as Phase 1 VM) — change on production
if id sls &>/dev/null; then
  echo 'sls:20260717' | chpasswd 2>/dev/null || true
  echo
  echo "Lab password set for user sls: 20260717 (change on production)"
fi

echo
echo "Done. Reboot; expect autologin as sls and SLS Camera."
echo "Captures: /data/sls-captures  (and this stick's sls-captures/ if Auto + mounted)"
echo "SSH (lab): see SSH-LAB.txt on this stick — install openssh-server once on network."
INSTALL
chmod +x "$MNT/install-from-usb.sh" 2>/dev/null || true

# Lab SSH handoff (OptiPlex agent access) — not a field product requirement
cat >"$MNT/SSH-LAB.txt" <<'SSHLAB'
SLS lab tablet — SSH access (OptiPlex / agent)
=============================================
Password (lab, same as VM):  sls / 20260717
  Temporary Lubuntu install user: use the same password if you created one.

1) After Lubuntu is on eMMC (not live-only), get network (Wi-Fi, phone tether, or USB Ethernet).

2) Install SSH (needs network once):
     sudo apt update
     sudo apt install -y openssh-server
     sudo systemctl enable --now ssh

3) Show IP for the build host:
     ip -br a

4) From OptiPlex:
     ssh sls@TABLET_IP
     # password: 20260717

5) Then run appliance from this stick (if not done yet):
     cd /media/$USER/SLS-MEDIA || cd /run/media/$USER/SLS-MEDIA
     bash install-from-usb.sh
     sudo reboot

Test unit today: tablet-01 RCA W101AS23T2 + Kinect (portable PSU + USB).
SSHLAB

# Bootstrap doc
cat >"$MNT/BOOTSTRAP.md" <<'BOOT'
# SLS blow-and-go — Stage A (field USB)

## Contents

| Path | Purpose |
|------|---------|
| `install-from-usb.sh` | One-shot appliance install (run after OS install) |
| `firmware/` | Offline debs, wheels, model, pinned app, overlay |
| `SSH-LAB.txt` | Lab SSH: openssh-server + `sls` / `20260717` |
| `sls-captures/` | Investigation media (Auto captures when stick mounted) |
| `optional/` | Lubuntu ISO if included (for Ventoy) |

## Steps

### 1. Install Lubuntu 26.04

Boot **Lubuntu 26.04 desktop** amd64 (same series as offline debs).

- If `optional/lubuntu-*.iso` is on this stick, use **Ventoy** (or Rufus) so you can boot the ISO from the stick while keeping the data partition.
- Or use a separate installer USB.

Install to internal eMMC/SSD. Temp admin password (lab): **20260717**.

**Today’s unit:** tablet-01 **RCA W101AS23T2** + Kinect (portable PSU + USB).

### 2. Lab SSH (so build host / agent can help)

See **`SSH-LAB.txt`**. Short version:

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
ip -br a
# From OptiPlex: ssh sls@TABLET_IP   (password 20260717 after appliance)
```

### 3. Run appliance install

```bash
# mount SLS-MEDIA if not auto-mounted
cd /media/$USER/SLS-MEDIA    # or /run/media/$USER/SLS-MEDIA
bash install-from-usb.sh
```

### 4. Reboot

- Autologin: **sls**
- Lab password: **20260717** — change on production hardware
- App should start; Quit → power off (exit 10 + launcher)

### 5. Kinect

- Power brick + USB on the **tablet** (no VM passthrough)
- Optional mic: `sudo apt install kinect-audio-setup` (MS firmware; not on this stick)

## Rebuild this stick (on build host)

```bash
cd ~/sls-camera-firmware
./scripts/10-fetch-offline.sh && ./scripts/20-sync-app.sh
sudo ./scripts/50-build-field-usb.sh /dev/sdX1
```
BOOT

# README for humans opening the stick in a file manager
cat >"$MNT/README-SLS.txt" <<'EOF'
SLS Camera — field USB (Stage A blow-and-go)
============================================
1) Install Lubuntu 26.04 to the tablet (ISO in optional/ if present, or separate media).
2) Lab SSH: see SSH-LAB.txt  (openssh-server; password sls / 20260717)
3) On the tablet, open this stick and run:  bash install-from-usb.sh
4) Reboot. Autologin: sls

Details: BOOTSTRAP.md
Captures folder: sls-captures/
Test tablet today: RCA W101AS23T2 + Kinect
EOF

# Optional ISO
if [[ -n "$ISO_SRC" && -f "$ISO_SRC" ]]; then
  echo "Copying ISO (large)…"
  mkdir -p "$MNT/optional"
  cp -v "$ISO_SRC" "$MNT/optional/"
  cat >"$MNT/optional/VENTOY.txt" <<'EOF'
To boot this ISO from the same stick:
  1) Install Ventoy to the stick FIRST (destroys partitions) OR use a second stick for Ventoy.
  2) Prefer: Ventoy stick for ISO boot + this data layout on a second partition/stick.

If you only copied the ISO here without Ventoy, use Rufus/dd to a different USB for install,
then use this stick solely as the firmware data volume.
EOF
fi

sync
echo
echo "=== Field USB ready ==="
du -sh "$MNT/firmware" "$MNT/sls-captures" 2>/dev/null
df -h "$MNT" | tail -1
ls -la "$MNT"

if [[ "${UNMOUNT_WHEN_DONE:-0}" == "1" ]]; then
  umount "$MNT" || true
  echo "Unmounted $TARGET"
fi

echo
echo "Next: install Lubuntu 26.04 on target, then run install-from-usb.sh from this stick."
