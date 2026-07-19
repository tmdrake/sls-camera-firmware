# Hardware tree (field units)

Catalog of tablets and shared sensor kits for SLS appliance wipe-and-load.  
App tracking: [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7) · UI fit [#6](https://github.com/tmdrake/sls-camera/issues/6).

## Fleet overview

| Unit ID | Role | Device doc | OS now | Wipe status |
|---------|------|------------|--------|-------------|
| **tablet-01** | RCA W101AS23T2 | [rca-w101as23t2.md](rca-w101as23t2.md) | Win10, 800×1280, 2 GB | **Not wiped** (Phase 1) |
| **tablet-02** | TMAX TM800W610L | [tablet-02.md](tablet-02.md) | Win10 x64, **1200×1920**, 2 GB | **Not wiped** (Phase 1) |
| **kinect-kit** | Shared sensor + power | [kinect-portable-power.md](kinect-portable-power.md) | n/a | Both tablets + portable PSU |

Both tablets are intended to run with a **Kinect 360 + portable power supply** for mobile investigations.

## Add / update a device from Windows msinfo

On the tablet: `msinfo32` → File → Export → save as e.g. `tablet-02.txt` on the pen drive.

On the build host:

```bash
cd ~/sls-camera-firmware
# stick mounted, e.g. /run/media/$USER/PEN\ DRIVE/tablet-02.txt
./scripts/import-msinfo.sh "/run/media/$USER/PEN DRIVE/tablet-02.txt" tablet-02
```

Creates/updates `docs/devices/<id>.md` draft from the export.

## Template

Blank form: [TEMPLATE.md](TEMPLATE.md)

## Wipe-load order (when Phase 1 stick path is solid)

1. Catalog both tablets (msinfo + photos) — **this step**  
2. Prove `install-from-usb.sh` on clean VM  
3. Wipe **tablet-02** first if disposable, or tablet-01 — Lubuntu 26.04 amd64 UEFI  
4. `bash install-from-usb.sh` from SLS-MEDIA stick  
5. Attach Kinect + portable PSU; fill pass/fail on each device page  
