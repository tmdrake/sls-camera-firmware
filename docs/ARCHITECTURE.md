# Firmware architecture

## Boot path (target appliance)

```text
Power on
  → bootloader
  → Linux kernel + init
  → display manager (LightDM / GDM) auto-login user `sls`
  → session (minimal LXQt / Openbox / Lubuntu stripped)
  → autostart: /usr/local/bin/sls-camera
  → Qt SLS app fullscreen (from /opt/sls-camera)
```

## Partitions (Phase 3 goal)

| Mount | Purpose |
|-------|---------|
| `/` | Rootfs (may become read-only later) |
| `/data` | Writable: captures, logs, optional config overrides |
| `/boot` | Kernel / EFI as needed |

Phase 1 may use a normal writable root with `/data` created early.

## Package layers

```text
┌─────────────────────────────────────────┐
│  SLS Qt app  (/opt/sls-camera + venv)   │
├─────────────────────────────────────────┤
│  Python wheels (offline) + MediaPipe    │
├─────────────────────────────────────────┤
│  freenect, PortAudio, ALSA, udev        │
├─────────────────────────────────────────┤
│  Ubuntu / Lubuntu base + touch stack    │
└─────────────────────────────────────────┘
```

## Offline install flow

```text
scripts/10-fetch-offline.sh   # build host, online once
        ↓
   vendor/debs + vendor/wheels + vendor/models
        ↓
scripts/20-sync-app.sh        # pin sls-camera
        ↓
scripts/install-appliance.sh  # target tablet (offline OK if vendor filled)
```

## ISO flow (Phase 2)

```text
base ISO or bootstrap
  → chroot hooks (hooks/)
  → inject overlay/
  → inject vendor packages offline
  → produce out/sls-camera-firmware-YYYYMMDD.iso
```

Toolchain choice (live-build vs Cubic vs mkosi) is deferred until Phase 1 is proven on hardware.

## Kinect

- Blacklist `gspca_kinect` (see `overlay/etc/modprobe.d/`)  
- USB udev modes for NUI motor/audio/camera  
- Depth always freenect **640×480**; app composites to 1280×720  
- Audio: optional `kinect-audio-setup` — **not** bundled as MS firmware in public trees  
