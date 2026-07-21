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
| BIOS mode | **UEFI** (ia32 GRUB on this unit) | Match ISO boot mode; 30s delay = GRUB recordfail — [EFI-BOOT.md](../EFI-BOOT.md) |
| Secure Boot | **Off** | Good for Lubuntu |
| TPM / BitLocker auto | Not usable | Fine for field Linux |
| Display | **Intel HD Graphics** (Cherry Trail, DEV_22B0) | |
| Resolution (Windows) | **800 × 1280 @ 59 Hz** | Native **portrait**; appliance locks **1280×800** landscape |
| Storage | **Biwin ~28.8 GB** fixed disk | ~28 GB C: NTFS, ~16.6 GB free at capture time |
| Free for Linux | Tight if dual-boot; full wipe OK for appliance | Aim minimal install |
| Touch | **Goodix** (`GDIX1002:00`) | **Intermittent I2C death** on Linux (probe -110); cold boot often fixes — [TOUCH-GOODIX.md](../TOUCH-GOODIX.md) |
| USB | Intel USB 3.0 xHCI (22B5) | Prefer direct port for Kinect |
| Windows | 10 Home 19044 | Wipe candidate for Stage A field USB |

## Implications for blow-and-go

1. **Install Lubuntu 26.04 amd64** (UEFI). Do not use i386 ISO.  
2. **RAM 2 GB:** use lightweight session (already LXQt); consider `zram`; monitor OOM during pose — [PERFORMANCE.md](../PERFORMANCE.md).  
3. **Landscape lock:** native glass is **800×1280** portrait; firmware forces **1280×800** via `sls-lock-landscape` with **`SLS_LANDSCAPE_ROTATE=right`** + touch CTM/map-to-output (live-validated fleet policy).  
4. **~29 GB eMMC:** full-disk Lubuntu + `/opt/sls-camera` venv is OK; leave room for `/data/sls-captures`.  
5. **Kinect:** external brick + USB; after wipe, no VM passthrough script.  
6. **Goodix touch:** first boot checklist item — if no touch, keyboard/SSH fallback.  

## Linux driver reality (lab 2026-07)

This unit **can** run the SLS appliance (Lubuntu 26.04, autologin, app, quit→poweroff, landscape), but **Cherry Trail + vendor ACPI** makes it a rough Linux citizen. Expect more “platform” pain than app bugs.

| Area | Reality on this RCA |
|------|---------------------|
| **SLS app path** | Works once install + Kinect 12 V are right |
| **Goodix touch** | Usually OK in field (**OTG port not used** for normal SLS). Lab only: hub/NIC on **OTG** killed Goodix (I2C -110); unplug restored touch — [TOUCH-GOODIX.md](../TOUCH-GOODIX.md) |
| **Boot delay ~30 s** | Usually GRUB **recordfail** after hard off (fixed with `GRUB_RECORDFAIL_TIMEOUT=0`) — [EFI-BOOT.md](../EFI-BOOT.md); residual OEM EFI quirks possible |
| **UEFI** | **ia32** GRUB on 32-bit firmware + amd64 OS — normal for this class, still fiddly |
| **Kinect** | Not a tablet driver issue if only `02b0`; **12 V / charger path** — [kinect-portable-power.md](kinect-portable-power.md) |
| **CPU / RAM** | Z8350 + **2 GB** — MediaPipe is CPU-bound; usable, not snappy — [PERFORMANCE.md](../PERFORMANCE.md) |
| **Audio / SOF** | Journal noise (`sof-audio` no machine) — non-blocking for depth SLS |
| **i2c / pinctrl** | Occasional designware timeouts, pinctrl probe errors — same generation as touch flakiness |

**Takeaway for BOM:** fine as a **lab / wipe-load proving** tablet; for **production fleet**, prefer a better-supported SoC (e.g. N100-class) if driver tax stays high. Do not over-invest in Goodix/ACPI heroics on this chassis unless volume forces it.

### OTG port (this unit only — not normal field use)

**Field kit does not use the OTG/USB host port** for SLS (Kinect + power are separate). Keep this as a **lab gotcha** only:

- Loading OTG with a **hub / Ethernet dongle / heavy bus-powered gear** can brown out rails and **kill Goodix touch** (I2C timeout).  
- Unplugging OTG restored touch immediately in lab (2026-07-21).  
- If someone plugs lab debug gear into OTG and touch dies: remove that USB first.

### Charger plugs in → tablet powers on

**Observed:** attaching the dedicated 5 V charger can **power the unit on by itself** (LED/hardware path). Common on cheap tablets; usually **EC/firmware**, not Linux or Windows choosing it.

| Approach | Realistic on this RCA? |
|----------|-------------------------|
| **UEFI/setup “Power on AC”** | Often **no** menu item on AMI/vendor Cherry Trail; if present, disable “Wake on AC / Power on by AC” |
| **Windows** | Same EC behavior under Win10; rare advanced power options; not a clean “charge only” mode |
| **Linux after boot** | Could auto-`poweroff` if AC online — **unreliable here**: `axp288_charger/online` often stays **0** even with brick + charge LED (see lab charge notes) |
| **Practical lab** | Accept wake-on-plug; or charge while already off and unplug carefully; don’t fight EC unless a BIOS toggle appears |
| **Appliance helper** | `sls-charge-idle-poweroff` — if charge is **detected** for **15 min**, power off (unattended charge; Kinect unusable on this dedicated charger) — [CHARGE-IDLE-POWEROFF.md](../CHARGE-IDLE-POWEROFF.md) |

**Fleet contrast:** tablet-02 charges via **OTG control circuit** and may run while powered — set `ENABLED=0` in `/etc/sls/charge-idle.conf` on that class so it does not auto-shutdown.

## Phase 1 / wipe status

- **Wiped** Lubuntu 26.04 appliance (lab): boot → app → shutdown OK; touch/Kinect power are the main field risks.  
- Fill pass/fail on [HARDWARE-MATRIX](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/HARDWARE-MATRIX.md) / #7 as QA continues.

## Files

- Raw export (operator USB): `tablet.txt` (UTF-16 msinfo)  
- This summary: `docs/devices/rca-w101as23t2.md`  
