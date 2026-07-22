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
  --exclude 'screenshots' \
  --exclude '.grok/' \
  "$ROOT/" "$MNT/firmware/"
# FAT32 cannot store symlinks (repo root screenshots -> docs/images). Images: firmware/docs/images/
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
echo "Done. Next:"
echo "  1) Kinect audio (if spectrum still default):"
echo "       sudo bash $HERE/firmware/scripts/install-kinect-audio-on-target.sh"
echo "       unplug/replug Kinect; arecord -l"
echo "  2) Reboot — autologin sls, SLS Camera"
echo "Captures: /data/sls-captures  (and this stick's sls-captures/ if Auto + mounted)"
echo "SSH (lab): see SSH-LAB.txt — openssh-server once on network."
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

### 3. Run appliance install (also the **upgrade** path)

First install **or** refresh an older appliance **without wiping Lubuntu**:

```bash
# mount SLS-MEDIA if not auto-mounted
cd /media/$USER/SLS-MEDIA    # or /run/media/$USER/SLS-MEDIA
bash install-from-usb.sh
```

Same script re-applies app tree, overlay, and seeds. Future auto-upgrade: [docs/UPGRADE.md](docs/UPGRADE.md).

Install applies (must not skip on rebuild):

| Setup item | What |
|------------|------|
| **App + launcher** | `/opt/sls-camera` + `/usr/local/bin/sls-camera`; **menu + Desktop** “SLS Camera” |
| **No motor (field)** | Launcher injects **`--no-auto-level`** (no tilt on open). Lab: `SLS_KINECT_AUTO_LEVEL=1` |
| **GRUB fast loader** | `GRUB_RECORDFAIL_TIMEOUT=0` + `grub.d/50-sls-recordfail.cfg` — no ~30–38 s “EFI” hang after hard power-off ([EFI-BOOT.md](docs/EFI-BOOT.md)). Lab: loader ~6 s when set. |
| **SDDM autologin** | `User=sls`, `Session=Lubuntu`, **`Relogin=true`** |
| **Quit → power off** | `/etc/sudoers.d/sls-poweroff` (passwordless `poweroff` for `sls`) |
| **RCA speakers** | SST + `sls-audio-speakers` (Speaker/HP path + **OUT volume 39**) |
| **Date & time** | polkit timedate + `sudoers.d/sls-timedate` (Settings without root password) |
| Backlight / PMIC / Kinect seeds | As in install-appliance |

### 4. Reboot

- Prefer **cold power-off → power on** on RCA after first install (SST/I2C).
- Autologin: **sls** (no greeter)
- Lab password: **20260717** — change on production hardware
- App should start; if desktop only: **Applications → SLS Camera** or `sls-camera` / `sls-camera --demo`
- Quit → power off (exit 10 + launcher); tilt motor should **not** move on open
- Boot should be **fast at GRUB** — if ~30 s delay returns, re-check `RECORDFAIL` (see EFI-BOOT.md)

### 5. Kinect audio (**required** for spectrum / Record mic)

Depth uses freenect (already in appliance install). **Mic** needs MS UAC firmware:

```bash
# From this stick (after install-from-usb), if spectrum still says "default":
cd /media/$USER/SLS-MEDIA/firmware   # or /run/media/$USER/SLS-MEDIA/firmware
sudo ./scripts/install-kinect-audio-on-target.sh
# Unplug/replug Kinect USB (operate 12V power on)
arecord -l
```

Build host must run `./scripts/10-fetch-offline.sh` so the stick has `kinect-audio-setup` deb + `vendor/kinect/UACFirmware`.

### 6. Kinect depth

- Power brick + USB on the **tablet** (operate 12 V path; no VM passthrough)

## Rebuild this stick (on build host)

```bash
cd ~/sls-camera-firmware
# Prefer local app tree when unpushed field fixes matter:
#   APP_SRC=~/sls-camera ./scripts/20-sync-app.sh
./scripts/10-fetch-offline.sh && ./scripts/20-sync-app.sh
./scripts/50-build-field-usb.sh /run/media/$USER/SLS-MEDIA
# or: sudo ./scripts/50-build-field-usb.sh /dev/sdX1
```

**When rebuilding the installer/stick, keep these setup fixes in the tree** (do not regress):

1. **`overlay/etc/default/grub.d/50-sls-recordfail.cfg`** + install-appliance GRUB block → fast loader  
2. **`overlay/etc/sddm.conf.d/50-sls-autologin.conf`** (`Relogin=true`)  
3. **`overlay/etc/sudoers.d/sls-poweroff`** → app Quit exit 10 actually powers off  
4. **`overlay/usr/local/bin/sls-audio-speakers`** + service (OUT volume + Speaker/HP)  
5. Kinect EULA debconf preseed before seed apt  
6. **`overlay/usr/local/bin/sls-camera`** → default **`--no-auto-level`** (no motor)  
7. **`overlay/usr/share/applications/sls-camera.desktop`** → menu + Desktop icon  
8. **`overlay/etc/polkit-1/rules.d/60-sls-timedate.rules`** + `sudoers.d/sls-timedate`  
9. Pin current app (`packages/app-ref.txt` + `20-sync-app.sh`) — battery UI, TTS async, etc.

Verify after tablet install: `systemd-analyze` (loader ≪ 30 s), autologin, `sudo -n /usr/sbin/poweroff --help`, DrakeVox audible, `which sls-camera` + menu entry, motor quiet on open.
BOOT

# README for humans opening the stick in a file manager
cat >"$MNT/README-SLS.txt" <<'EOF'
SLS Camera — field USB (Stage A blow-and-go)
============================================
1) Install Lubuntu 26.04 to the tablet (ISO in optional/ if present, or separate media).
2) Lab SSH: see SSH-LAB.txt  (openssh-server; password sls / 20260717)
3) On the tablet, open this stick and run:  bash install-from-usb.sh
4) Kinect AUDIO (required for spectrum/Record mic):
     cd firmware && sudo ./scripts/install-kinect-audio-on-target.sh
     Unplug/replug Kinect; arecord -l
5) Cold power cycle (RCA). Autologin: sls. GRUB should be FAST (no ~30s hang).
6) DrakeVox sound: speakers need OUT volume — install runs sls-audio-speakers.

Details: BOOTSTRAP.md · docs/EFI-BOOT.md · docs/FIRST-BOOT.md
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
