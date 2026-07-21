# vendor/ (offline cache)

This directory holds **regenerated** offline assets. They are **gitignored** except this README.

```bash
../scripts/10-fetch-offline.sh
../scripts/20-sync-app.sh
```

| Subdir | Purpose |
|--------|---------|
| `debs/` | Ubuntu `.deb` packages (freenect, kinect-audio-setup, …) |
| `wheels/` | Python wheels |
| `models/` | MediaPipe `.task` |
| `kinect/` | **Private:** `UACFirmware` for Kinect mic (gitignored; `FETCH_KINECT_UAC=1`) |
| `sls-camera/` | App tree at pinned commit |

**Easy full offline pack (build host with network once):**

```bash
./scripts/10-fetch-offline.sh    # debs + wheels + model + vendor/kinect/UACFirmware
./scripts/20-sync-app.sh
sudo ./scripts/50-build-field-usb.sh /path/to/SLS-MEDIA
```

Do **not commit** `vendor/kinect/` (Microsoft non-redistributable). Private field sticks may include it.
