# SLS Camera Firmware

**Tablet / appliance firmware** for the [SLS Camera](https://github.com/tmdrake/sls-camera) field app.

This repository builds and packages an **easy-to-use Linux image** so a touchscreen tablet can:

1. Boot with **no interactive login** (auto-login kiosk user)  
2. **Install / reinstall** freenect, system libraries, and the SLS app in one shot  
3. Run **offline** from a vendored cache of debs, Python wheels, and the MediaPipe pose model  
4. Store investigation captures on a **writable data path** (`/data/sls-captures`) even if root is later locked down  

The **application source of truth** remains **`sls-camera`**. This repo is packaging + ISO only.

| Repo | Role |
|------|------|
| [`sls-camera`](https://github.com/tmdrake/sls-camera) | Qt SLS app, freenect bring-up, DrakeVox, recording |
| **`sls-camera-firmware`** (this repo) | Offline mirror, appliance install, future tablet ISO |

## Goals (product)

- **Blow-and-go:** flash or run install → tablet is ready for investigations  
- **Touch-friendly:** light desktop (Lubuntu/LXQt-class), app already uses large controls  
- **Kinect 360 ready:** freenect, gspca blacklist, udev, PortAudio  
- **Offline rebuild:** `vendor/` holds packages so field techs are not blocked by no Wi‑Fi  
- **Simple:** operators never need to `git pull` or `pip install` on the tablet  

## Phases

| Phase | Deliverable | Status |
|-------|-------------|--------|
| **0** | Repo scaffold, docs, offline fetch + app sync scripts | **Done** (recursive offline debs) |
| **1** | `install-appliance.sh` on a blank Ubuntu/Lubuntu install (offline) | **Proven on Lubuntu 26.04 VM** (`--demo` smoke) |
| **2** | Blow-and-go media: **Stage A field USB** now; single ISO later | **Stage A scripts ready** |
| **3** | Read-only root + `/data`, power policy, factory reset | Later |

### Screenshots (Phase 1 VM)

See [docs/FIRST-BOOT.md](docs/FIRST-BOOT.md) and [docs/images/](docs/images/README.md) — Lubuntu desktop + SLS `--demo` UI.

### Rebuild the test VM

→ **[docs/VM-REBUILD.md](docs/VM-REBUILD.md)** (lab user **`sls` / `20260717`**)

### Blow-and-go field USB (Phase 2 Stage A)

**Build + install instructions:** → **[docs/ISO-AND-FIELD-USB.md](docs/ISO-AND-FIELD-USB.md)**

```bash
cd ~/sls-camera-firmware
./scripts/10-fetch-offline.sh && ./scripts/20-sync-app.sh
sudo ./scripts/prep-sls-media-usb.sh /dev/sdX      # wipe stick
sudo ./scripts/50-build-field-usb.sh /dev/sdX1     # copy firmware
# On tablet after Lubuntu 26.04 install:
#   bash /media/$USER/SLS-MEDIA/install-from-usb.sh && sudo reboot
```

## Quick start (build host)

```bash
cd ~/sls-camera-firmware
./scripts/00-check-host.sh
./scripts/10-fetch-offline.sh
./scripts/20-sync-app.sh
./scripts/30-build-iso.sh status
# Field USB: see docs/ISO-AND-FIELD-USB.md
# Phase 1 on a machine: sudo ./scripts/install-appliance.sh  (careful)
```

## Directory map

```text
sls-camera-firmware/
  docs/           Architecture, build, offline mirror, first-boot, hardware
  packages/       apt + Python package lists, pinned app commit
  scripts/        fetch, sync, install-appliance, build-iso stubs
  overlay/        files for target rootfs (autologin, udev, launcher)
  hooks/          chroot / live-build hooks (Phase 2)
  vendor/         offline debs/wheels/models (gitignored; regenerate)
  build/          work tree (gitignored)
  out/            ISO output (gitignored)
```

## Offline / vendor cache

See [docs/OFFLINE-MIRROR.md](docs/OFFLINE-MIRROR.md).

**Start here (app + FW shared rules):**  
[FOR-FIRMWARE-TEAM.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FOR-FIRMWARE-TEAM.md)  
— golden rules, `install-apt-deps.sh`, smoke checklist, quit exit codes.

**Dependency & version-conflict tracking** lives on the app repo (not only here):

- [sls-camera#2](https://github.com/tmdrake/sls-camera/issues/2) — offline recursive deps / installer (**closed**; use `install-apt-deps.sh`)  
- [sls-camera#3](https://github.com/tmdrake/sls-camera/issues/3) — apt/Python conflicts (**open tracker**)  

**Do not** commit Microsoft Kinect **UAC audio firmware** (non-redistributable). Document private drop or operator `kinect-audio-setup` install separately.

## Captures

Appliance default: **`/data/sls-captures`**. Launcher sets `SLS_CAPTURES_DIR` when that directory exists. The app **honors** `SLS_CAPTURES_DIR` for the local captures root.

## Related app docs

- [FOR-FIRMWARE-TEAM.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FOR-FIRMWARE-TEAM.md) (offline apt + contracts)  
- [FIELD-INSTALL.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FIELD-INSTALL.md) (dev host packaging)  
- [PRODUCT-VISION.md](https://github.com/tmdrake/sls-camera/blob/main/docs/PRODUCT-VISION.md)  
- [UBUNTU-SETUP.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/UBUNTU-SETUP.md)  

## License

Application code is covered by the **sls-camera** license. Firmware packaging scripts here are provided for the same project; third-party packages retain their own licenses.
