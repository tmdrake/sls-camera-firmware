# Device: TMAX TM800W610L

**Unit ID:** `tablet-02`  
**Hostname (Windows):** `TABLET-RONBDNC7`  
**Source:** Windows 10 `msinfo32` export `tablet-2.txt` on USB “SD CARD” (2026-07-18).  
**Tracking:** [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7) · UI fit [#6](https://github.com/tmdrake/sls-camera/issues/6)  
**Field kit:** Kinect 360 + portable power — [kinect-portable-power.md](kinect-portable-power.md)

## Summary

| Field | Value | SLS notes |
|-------|--------|-----------|
| Manufacturer | **TMAX** | Budget slate |
| Model | **TM800W610L** | Board same name |
| CPU | **Intel Atom x5-Z8300** @ 1.44 GHz (4C/4T, Cherry Trail) | 64-bit capable; similar class to tablet-01 Z8350 — expect low FPS |
| RAM | **2.00 GB** | Same tight RAM class as tablet-01 |
| System type (Windows) | **x64-based PC** | **64-bit Windows** — amd64 Lubuntu is correct |
| Platform role | Slate | |
| OS (when captured) | Windows 10 Home **19042** | Wipe candidate |
| BIOS | JK-BI-8-HLK80CR100-C34A-101-H-LCD2 (2017-03-02) | |
| BIOS mode | **UEFI** | Match ISO boot |
| Secure Boot | **Off** | Good for Lubuntu |
| Display | Intel HD Graphics (Cherry Trail) | |
| Resolution (Windows) | **1200 × 1920 @ 60 Hz** | Native **portrait** glass; appliance locks **1920×1200** landscape |
| Storage (fixed) | **SanDisk DF4032 ~29.1 GB** (3 partitions) | Same ~32 GB class eMMC as tablet-01 |
| Removable (at capture) | Generic SD32G ~29 GB | Export media only |
| Touch | *Not clear in msinfo* — verify after Linux | Check Goodix/i2c-hid on wipe |
| USB | (see Device Manager after wipe) | Kinect + portable PSU data cable |

## Comparison to tablet-01 (RCA W101AS23T2)

| | tablet-01 | tablet-02 |
|--|-----------|-----------|
| Brand / model | RCA W101AS23T2 | TMAX TM800W610L |
| CPU | Atom x5-**Z8350** | Atom x5-**Z8300** |
| RAM | 2 GB | 2 GB |
| Windows bitness | X86 (likely 32-bit Win) | **x64** |
| Resolution (native) | **800×1280** portrait | **1200×1920** portrait |
| Appliance locked | **1280×800** landscape | **1920×1200** landscape |
| Storage | Biwin ~29 GB | SanDisk DF4032 ~29 GB |
| Secure Boot | Off | Off |
| Field kit | Kinect + portable PSU | Same class |

Both are **Cherry Trail 2 GB slates** with portrait-native glass — firmware **locks landscape** for the same appliance UI profile (`sls-lock-landscape`).

## Implications for blow-and-go

1. Install **Lubuntu 26.04 amd64**, UEFI.  
2. **2 GB RAM** — same caveats as tablet-01 (zram, light session).  
3. **Landscape lock** — expect **1920×1200** after login; log geometry if Settings still clips (#6).  
4. **~29 GB** disk — full wipe, single OS, `/data/sls-captures`.  
5. Kinect + portable power on hand (fleet kit).  

## Appliance status

| Check | Result | Date |
|-------|--------|------|
| Lubuntu 26.04 install | pending | |
| install-from-usb | pending | |
| Touch | pending | |
| Kinect + portable PSU | hardware available | |
| Settings usable (scroll) | pending | |
| Captures | pending | |
| Quit power-off | pending | |

## Notes

- Imported from `tablet-2.txt` on SD CARD media.  
- Phase 1: do not wipe until field USB path is proven on a clean VM.  
