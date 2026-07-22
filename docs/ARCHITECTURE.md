# Firmware architecture

## Validation tracks (hardware-first)

**One installer**, designed for **field tablets**. The Phase 1 KVM guest is for **app + packaging smoke only** — not field audio, PMIC, or touch truth.

| Track | Where | Truth for |
|-------|--------|-----------|
| **Field (RCA first, then TMAX)** | Bare metal + SLS-MEDIA wipe/reload | Speakers (SST + OUT vol), PMIC/Goodix, landscape+CTM, native Kinect USB, Quit→poweroff |
| **Phase 1 VM** | KVM/QEMU tablet-class (2 GiB / 2 vCPU) | App UI, Settings, TTS *latency* under load, install-appliance script regression |

```text
VM green ≠ field audio green
App change  → optional VM --demo / TTS smoke
Installer / audio / touch / PMIC  → rebuild stick → RCA (or fleet unit)
Ship bar  → field checklist green
```

**“Designed for both”** means field defaults + **safe skips** on hypervisor (landscape CTM, SST/speakers, PMIC), not two product installers. See [VM-REBUILD.md](VM-REBUILD.md) and [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md).

**Lab lesson:** on the VM, **`./run.sh --demo` / desktop shortcut** was a strong app smoke **before** full appliance install. Keep that for app team; use wipe + SLS-MEDIA on hardware for installer freeze.

**Field audio (SST / `sls-audio-speakers` / PMIC)** is tablet-only. Installing SST `dsp_driver=2` on KVM kills guest HDA → Dummy Output. Installer skips those on virt (`SLS_FIELD_AUDIO` / `SLS_FIELD_PMIC` auto).

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
