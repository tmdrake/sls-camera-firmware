# Build host guide

## Requirements (Phase 0–1)

- Ubuntu 22.04 / 24.04 / 26.04 x86_64 (or similar) with network for first offline fetch  
- `git`, `curl`, `python3`, `python3-venv`, `sudo`  
- Optional: `uv` or `pip` for wheel download  
- Disk: several GB free under `vendor/` and `build/`  

## Steps

### 1. Check host

```bash
./scripts/00-check-host.sh
```

### 2. Fetch offline cache (online)

```bash
./scripts/10-fetch-offline.sh
```

Creates:

- `vendor/debs/*.deb`  
- `vendor/wheels/*`  
- `vendor/models/pose_landmarker_lite.task`  

### 3. Sync application

```bash
# default: clone/update github.com/tmdrake/sls-camera at packages/app-ref.txt
./scripts/20-sync-app.sh

# or pin explicitly
APP_REF=0348fa0 APP_URL=https://github.com/tmdrake/sls-camera.git ./scripts/20-sync-app.sh

# local sibling checkout
APP_SRC=~/sls-camera ./scripts/20-sync-app.sh
```

### 4. Appliance install (Phase 1 — on target)

**Warning:** modifies system users, packages, and autologin. Prefer a dedicated tablet or VM.

```bash
sudo ./scripts/install-appliance.sh
```

### 5. ISO (Phase 2)

```bash
./scripts/30-build-iso.sh   # currently documents next steps; not a full ISO yet
```

## Flashing (later)

When an ISO exists in `out/`:

- **Ventoy** or `dd` to USB (document exact command only with confirmation flags)  
- Install to internal eMMC/SSD via Ubiquity/Calamares customized for appliance  

See `scripts/install-to-device.sh` (gated; not for casual use).
