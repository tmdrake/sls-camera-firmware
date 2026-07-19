# Device: tablet-02 (second field unit)

**Unit ID:** `tablet-02`  
**Status:** Catalog **pending full msinfo** — unit exists; Kinect + portable PSU same class as tablet-01.  
**Tracking:** [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7)

## Summary

| Field | Value | SLS notes |
|-------|--------|-----------|
| Manufacturer | *TBD — drop `tablet-02.txt` msinfo on pen drive* | |
| Model | *TBD* | |
| CPU | *TBD* | Must be **x86_64-capable** for current amd64 pack |
| RAM | *TBD* | Compare to tablet-01 (2 GB) |
| BIOS mode | *TBD* | Prefer UEFI, Secure Boot off or Other OS |
| Resolution | *TBD* | Critical for Settings UI (#6) |
| Storage | *TBD* | |
| Touch | *TBD* | |
| Field kit | Kinect 360 + **portable power** | Same kit class as tablet-01 — [kinect-portable-power.md](kinect-portable-power.md) |

## How to complete this page

On tablet-02 (Windows):

1. `Win+R` → `msinfo32` → File → **Export** → `tablet-02.txt` on the pen drive.  
2. Optional: Display Settings screenshot (resolution + scale %).  

On build host:

```bash
cd ~/sls-camera-firmware
./scripts/import-msinfo.sh "/run/media/$USER/PEN DRIVE/tablet-02.txt" tablet-02
```

Then edit this file with any manual notes (PSU model, which USB port for Kinect, photos).

## Appliance status

| Check | Result | Date |
|-------|--------|------|
| Lubuntu 26.04 install | pending | |
| install-from-usb | pending | |
| Touch | pending | |
| Kinect + portable PSU | pending (hardware on hand) | |
| Settings usable | pending | |
| Captures | pending | |
| Quit power-off | pending | |

## Notes

- Both tablets currently have Kinect attached with portable power for field-style layout practice.  
- Stay on Phase 1 until field USB install is proven; then wipe-load one unit first.  
