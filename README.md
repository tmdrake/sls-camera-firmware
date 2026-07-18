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
| **2** | Bootable **ISO** (live-build / Cubic / mkosi) | Later |
| **3** | Read-only root + `/data`, power policy, factory reset | Later |

### Screenshots (Phase 1 VM)

See [docs/FIRST-BOOT.md](docs/FIRST-BOOT.md) and [docs/images/](docs/images/README.md) — Lubuntu desktop + SLS `--demo` UI.

## Quick start (build host)

```bash
# Clone next to sls-camera (recommended layout)
cd ~
git clone https://github.com/tmdrake/sls-camera-firmware.git   # when remote exists
# or work from this tree

cd sls-camera-firmware
./scripts/00-check-host.sh

# Optional: refresh offline cache (needs network once)
./scripts/10-fetch-offline.sh

# Sync pinned sls-camera into build/app (or vendor/sls-camera)
./scripts/20-sync-app.sh

# Phase 1: install onto THIS machine as appliance (sudo; careful)
# ./scripts/install-appliance.sh

# Phase 2: ISO (stub until toolchain chosen)
# ./scripts/30-build-iso.sh
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

**Dependency & version-conflict tracking** lives on the app repo (not only here):

- [sls-camera#2](https://github.com/tmdrake/sls-camera/issues/2) — offline recursive deps / installer  
- [sls-camera#3](https://github.com/tmdrake/sls-camera/issues/3) — apt/Python conflicts  

**Do not** commit Microsoft Kinect **UAC audio firmware** (non-redistributable). Document private drop or operator `kinect-audio-setup` install separately.

## Captures

Appliance default: **`/data/sls-captures`**. Launcher sets `SLS_CAPTURES_DIR` when that directory exists. App support for the env var may be added in `sls-camera`; until then path is prepared for firmware.

## Related app docs

- [FIELD-INSTALL.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FIELD-INSTALL.md) (dev host packaging)  
- [PRODUCT-VISION.md](https://github.com/tmdrake/sls-camera/blob/main/docs/PRODUCT-VISION.md)  
- [UBUNTU-SETUP.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/UBUNTU-SETUP.md)  

## License

Application code is covered by the **sls-camera** license. Firmware packaging scripts here are provided for the same project; third-party packages retain their own licenses.
