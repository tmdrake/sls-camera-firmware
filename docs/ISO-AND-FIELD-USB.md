# Blow-and-go media — build & install

Phase 1 proved **`install-appliance.sh`** on clean Lubuntu 26.04 (VM + contracts with app pin `59ebee6`).  
Phase 2 packages that into **operator media**.

| Stage | What you get | Status |
|-------|----------------|--------|
| **A — Field USB** | Stick: offline firmware + `install-from-usb.sh`; use with stock Lubuntu 26.04 ISO | **Ready** |
| **B — Single ISO** | One image: OS + appliance | Planned (Cubic / live-build / mkosi) |

---

## Quick start (host → stick → tablet)

### A. Build host: refresh offline pack + app

```bash
cd ~/sls-camera-firmware

./scripts/00-check-host.sh
./scripts/10-fetch-offline.sh    # vendor/debs + wheels + model (needs network once)
./scripts/20-sync-app.sh         # pin from packages/app-ref.txt

./scripts/30-build-iso.sh status # readiness check
```

### B. Prepare the USB stick (destroys stick data)

Identify the stick carefully (`lsblk` — **not** NVMe):

```bash
lsblk -o NAME,SIZE,TRAN,RM,MODEL,LABEL,MOUNTPOINT
```

```bash
# Whole disk, e.g. SanDisk at /dev/sda
sudo ./scripts/prep-sls-media-usb.sh /dev/sda
```

Result: one FAT32 partition, label **`SLS-MEDIA`**, folder `sls-captures/`.

### C. Copy firmware payload onto the stick

```bash
# Partition is usually /dev/sda1 after prep
sudo ./scripts/50-build-field-usb.sh /dev/sda1
```

Optional — also copy Lubuntu ISO onto the stick (needs free space; ~3.6 G+):

```bash
sudo ISO=/var/lib/libvirt/images/lubuntu-26.04-desktop-amd64.iso \
  ./scripts/50-build-field-usb.sh /dev/sda1
```

Or via the Phase 2 entrypoint:

```bash
sudo ./scripts/30-build-iso.sh usb /dev/sda1
```

### D. Install on the tablet (or clean VM)

**1. Install Lubuntu 26.04** (amd64) to internal storage  

- Boot stock Lubuntu ISO (Ventoy, Rufus, or second USB).  
- Same Ubuntu series as the offline debs (**26.04**).  

**2. Plug in SLS-MEDIA**, open a terminal:

```bash
# Mount path may vary
cd /media/$USER/SLS-MEDIA
# or: cd /run/media/$USER/SLS-MEDIA

bash install-from-usb.sh
```

This runs `firmware/scripts/install-appliance.sh` (offline debs/wheels/app).

**3. Lab user (documented for rebuilds only)**

```bash
echo 'sls:20260717' | sudo chpasswd   # change on production tablets
sudo reboot
```

**4. After reboot**

| Expect | |
|--------|--|
| Autologin | user **`sls`** (SDDM) |
| App | SLS Camera starts |
| Quit | Power off (app exit 10 + launcher) |
| Captures | `/data/sls-captures` and/or stick `sls-captures/` if Auto + mounted |

**5. Kinect**

- Power brick + USB on the **tablet** (no VM passthrough).  
- Optional mic: `sudo apt install kinect-audio-setup` (MS firmware; **not** on the stick).  

---

## Stick layout (after step C)

```text
SLS-MEDIA/
  README-SLS.txt          ← open this first
  BOOTSTRAP.md            ← same steps as this doc
  install-from-usb.sh     ← run on tablet after Lubuntu install
  firmware/               ← full offline tree
    vendor/debs|wheels|models
    scripts/install-appliance.sh
    packages/app-ref.txt
    overlay/
    build/app/            ← pinned sls-camera
  sls-captures/           ← investigation media
  optional/               ← Lubuntu ISO if you passed ISO=
```

---

## What each script does

| Script | Role |
|--------|------|
| `10-fetch-offline.sh` | Download recursive debs + wheels + pose model → `vendor/` |
| `20-sync-app.sh` | Clone/checkout app at `packages/app-ref.txt` → `build/app/` |
| `prep-sls-media-usb.sh` | Wipe USB disk → FAT32 **SLS-MEDIA** |
| `50-build-field-usb.sh` | Copy firmware + write `install-from-usb.sh` / `BOOTSTRAP.md` |
| `30-build-iso.sh status` | Check readiness |
| `30-build-iso.sh usb …` | Alias for `50-build-field-usb.sh` |
| `install-appliance.sh` | On **target**: system install (user, packages, app, SDDM, quiet session) |

---

## Verify a built stick

```bash
# host, with stick mounted:
ls /media/$USER/SLS-MEDIA/install-from-usb.sh
ls /media/$USER/SLS-MEDIA/firmware/scripts/install-appliance.sh
ls /media/$USER/SLS-MEDIA/firmware/vendor/debs/*.deb | wc -l   # expect hundreds
test -f /media/$USER/SLS-MEDIA/firmware/build/app/software/linux/viewer/run.sh && echo app_ok
```

Or:

```bash
./scripts/40-verify-iso.sh          # checks out/ and optional MOUNT=
MOUNT=/media/$USER/SLS-MEDIA ./scripts/40-verify-iso.sh
```

---

## Stage B — single appliance ISO (not automated yet)

| Option | Notes |
|--------|--------|
| Cubic | GUI remaster of Lubuntu ISO |
| live-build | Scriptable |
| mkosi | Declarative |

Planned: embed `vendor/` + pre-run or first-boot `install-appliance.sh` → `out/sls-camera-firmware-*.iso`.  
Do **Stage A on a real tablet** before investing in Stage B.

---

## Lab credentials (rebuild / field USB docs)

| User | Password | Notes |
|------|----------|--------|
| **sls** | **20260717** | Appliance autologin; **lab only** — change on production |

Full KVM Phase 1 path: [VM-REBUILD.md](VM-REBUILD.md).  
First boot after appliance: [FIRST-BOOT.md](FIRST-BOOT.md).

---

## Related issues (app)

| Issue | Topic |
|-------|--------|
| [#6](https://github.com/tmdrake/sls-camera/issues/6) | Settings geometry / scroll |
| [#7](https://github.com/tmdrake/sls-camera/issues/7) | Screen variants + hardware tree |
| [#8](https://github.com/tmdrake/sls-camera/issues/8) | Format media from app |
