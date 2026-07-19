# Build host guide

## Requirements

- Ubuntu **26.04** x86_64 preferred (must match tablet series for offline debs)  
- `git`, `curl`, `python3`, `python3-venv`, `sudo`, `rsync`  
- Disk: several GB free under `vendor/` and `build/`  
- Optional: USB stick for field media  

## End-to-end: offline pack → field USB → tablet

**Clean instructions (recommended path):**  
→ **[ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md)**

Short form:

```bash
cd ~/sls-camera-firmware

# 1) Offline cache + app pin
./scripts/00-check-host.sh
./scripts/10-fetch-offline.sh
./scripts/20-sync-app.sh
./scripts/30-build-iso.sh status

# 2) Wipe USB (example /dev/sda — CHECK lsblk first)
sudo ./scripts/prep-sls-media-usb.sh /dev/sda

# 3) Write blow-and-go payload
sudo ./scripts/50-build-field-usb.sh /dev/sda1

# 4) On tablet: install Lubuntu 26.04, then:
#    bash /media/$USER/SLS-MEDIA/install-from-usb.sh
#    reboot → user sls
```

## Phase 1 only (install on this machine or a mounted tree)

**Warning:** `install-appliance.sh` mutates users, packages, display manager. Prefer a tablet/VM.

```bash
./scripts/10-fetch-offline.sh
./scripts/20-sync-app.sh
# from a copy of the tree on the target:
sudo ./scripts/install-appliance.sh
```

KVM rebuild: [VM-REBUILD.md](VM-REBUILD.md) (lab user **`sls` / `20260717`**).

## Script index

| Script | Purpose |
|--------|---------|
| `00-check-host.sh` | Host prerequisites |
| `10-fetch-offline.sh` | `vendor/debs` + wheels + model |
| `20-sync-app.sh` | Pin app → `build/app` |
| `install-appliance.sh` | Target appliance install |
| `prep-sls-media-usb.sh` | Wipe USB → FAT32 `SLS-MEDIA` |
| `50-build-field-usb.sh` | Copy firmware onto stick |
| `30-build-iso.sh` | Phase 2 entry (`status` / `usb`) |
| `40-verify-iso.sh` | Verify stick payload or `out/` |
| `vm-kinect-usb.sh` | Host-only Kinect passthrough for VM tests |

## Flashing (Stage B, later)

When a single ISO exists in `out/`:

- Ventoy or `dd` (document exact flags only with confirmation)  
- See `scripts/install-to-device.sh` (gated)

## Related docs

| Doc | Topic |
|-----|--------|
| [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md) | **Build & install blow-and-go** |
| [OFFLINE-MIRROR.md](OFFLINE-MIRROR.md) | Offline debs rules |
| [FIRST-BOOT.md](FIRST-BOOT.md) | After appliance install |
| [HARDWARE.md](HARDWARE.md) | Kinect, display, media stick |
