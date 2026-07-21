# Device: RCA W101AS23T2

**Unit ID:** `tablet-01`  
**Inventory / hostname (Windows):** `SLS-CAMERA`  
**Source:** Windows 10 `msinfo32` export `tablet.txt` on USB “PEN DRIVE” (2026-07-18).  
**Tracking:** [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7) hardware tree · UI fit [#6](https://github.com/tmdrake/sls-camera/issues/6)  
**Field kit:** Kinect 360 + portable power — [kinect-portable-power.md](kinect-portable-power.md)

## Summary

| Field | Value | SLS notes |
|-------|--------|-----------|
| Manufacturer | **RCA** | Budget slate |
| Model | **W101AS23T2** | |
| Board | RCA **WT9S10WW05** | |
| CPU | **Intel Atom x5-Z8350** @ 1.44 GHz (4C/4T, Cherry Trail) | 64-bit capable; slow for MediaPipe — expect lower FPS |
| RAM | **2.00 GB** (~1.93 GB usable) | **Tight** for Qt + pose; swap/zram helpful; avoid heavy desktop chrome |
| System type (Windows) | **X86-based PC** | Almost certainly **32-bit Windows 10**; still install **amd64 Lubuntu** (CPU is x86_64) |
| Platform role | Slate (tablet) | |
| BIOS | BSR4WEUS-S10W05-RCA-V29 (2018-07-14) | |
| BIOS mode | **UEFI** | Match ISO boot mode |
| Secure Boot | **Off** | Good for Lubuntu |
| TPM / BitLocker auto | Not usable | Fine for field Linux |
| Display | **Intel HD Graphics** (Cherry Trail, DEV_22B0) | |
| Resolution (Windows) | **800 × 1280 @ 59 Hz** | Native **portrait**; appliance locks **1280×800** landscape |
| Storage | **Biwin ~28.8 GB** fixed disk | ~28 GB C: NTFS, ~16.6 GB free at capture time |
| Free for Linux | Tight if dual-boot; full wipe OK for appliance | Aim minimal install |
| Touch | **Goodix** (`GoodixTouchDriver`) | Linux may need `goodix` / i2c-hid quirks — verify after wipe |
| USB | Intel USB 3.0 xHCI (22B5) | Prefer direct port for Kinect |
| Windows | 10 Home 19044 | Wipe candidate for Stage A field USB |

## Implications for blow-and-go

1. **Install Lubuntu 26.04 amd64** (UEFI). Do not use i386 ISO.  
2. **RAM 2 GB:** use lightweight session (already LXQt); consider `zram`; monitor OOM during pose.  
3. **Landscape lock:** native glass is **800×1280** portrait; firmware forces **1280×800** via `sls-lock-landscape` with **`SLS_LANDSCAPE_ROTATE=right`** + touch CTM/map-to-output (live-validated fleet policy).  
4. **~29 GB eMMC:** full-disk Lubuntu + `/opt/sls-camera` venv is OK; leave room for `/data/sls-captures`.  
5. **Kinect:** external brick + USB; after wipe, no VM passthrough script.  
6. **Goodix touch:** first boot checklist item — if no touch, keyboard/SSH fallback.  

## Phase 1 status

- Do **not** wipe until Stage A stick path is proven on a clean VM (`install-from-usb.sh`).  
- When wiped: fill pass/fail for Settings, touch, Kinect, captures, power-off in #7.

## Files

- Raw export (operator USB): `tablet.txt` (UTF-16 msinfo)  
- This summary: `docs/devices/rca-w101as23t2.md`  
