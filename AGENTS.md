# SLS Camera Firmware — agent notes

## Purpose

Build tablet/appliance **firmware** for the SLS Camera field app. Do not fork the app here; pin and install **`sls-camera`**.

## Rules

1. **App source** lives in `sls-camera` (sibling clone or `vendor/sls-camera` via `scripts/20-sync-app.sh`).  
2. **Never commit** Microsoft Kinect SDK / UAC firmware binaries to a public remote.  
3. **Never force-push** to `main` without user approval.  
4. Prefer **offline-first** install paths (`vendor/debs`, `vendor/wheels`).  
5. Destructive scripts (`install-to-device.sh`, disk wipe) must require an explicit env flag (e.g. `I_UNDERSTAND=1`).  
6. **Hardware-first:** design/validate installer overlay for **field tablets** (RCA/TMAX). Phase 1 **VM = app + packaging smoke only** — not field audio, PMIC, or touch. Do not claim field readiness from VM alone. Field-only pieces may auto-skip on hypervisor (`sls-lock-landscape`, SST/speakers, PMIC).  

## Key paths

| Path | Use |
|------|-----|
| `packages/apt-packages.txt` | Deb list for offline fetch |
| `packages/python-requirements.txt` | Wheel download list |
| `packages/app-ref.txt` | Pinned `sls-camera` commit |
| `overlay/` | Rootfs drops (autostart, udev, launcher) |
| `scripts/install-appliance.sh` | Phase 1 blow-and-go on a running Ubuntu host |

## Touch / kiosk

Target auto-login user: **`sls`**. Autostart: `overlay/home/sls/.config/autostart/sls-camera.desktop`.  
App is Qt fullscreen always-on-top (see sls-camera product vision).

## Captures

Prefer `/data/sls-captures` via `SLS_CAPTURES_DIR` so a locked rootfs still accepts media.
