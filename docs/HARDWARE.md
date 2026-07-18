# Hardware assumptions

## Sensor

- **Xbox 360 Kinect** (NUI): motor `045e:02b0`, audio `045e:02ad`, camera `045e:02ae`  
- External **Kinect power brick** required  
- USB 2.0 host; avoid hubs when possible  

## Compute

- Phase 1–2 primary target: **x86_64** tablet or mini-PC (Intel/AMD)  
- ARM64 tablets: later (re-fetch wheels/debs for arch)  

## Display

- Touchscreen preferred; app supports large Qt buttons + keyboard  
- Brightness: **app Settings owns it** (sysfs / brightnessctl / xrandr)  
- **Disable auto-rotate** and desktop auto-brightness fighting the app — see [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md)  

### Resolutions (field + test)

| Environment | Resolution | Notes |
|-------------|------------|--------|
| Phase 1 KVM guest (default Spice) | **1280×800** | Probed: avail ~1280×768 after LXQt panel, dpr=1.0, 96 dpi |
| Common cheap 8–10″ tablets | **1280×800** | Same class as VM; good BOM target |
| Many 10″ Windows tablets | **1920×1200** | Usually comfortable for Settings |
| Short / old panels | **1024×600** | Risk: Settings rows clip without scroll |

App depth canvas is **1280×720** composite; that fits 800p. **Settings** has grown (Captures, Power off on Quit, DrakeVox, …) with 44px touch buttons and **no scroll area** — bottom controls can sit off-screen on short heights or HiDPI.

**App / field tracking:**

- [sls-camera#6](https://github.com/tmdrake/sls-camera/issues/6) — log geometry + Settings scroll/clamp  
- [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7) — **screen variants + hardware tree** (wipe real tablets, device matrix for other BOM)

## Power

- Prefer **external DC** for Kinect + tablet during investigations  
- App shows battery % when present  
- **Disable suspend / lid sleep / idle blank** on appliance images (`logind` drop-in + session `xset`) — [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md)  
- Full “inhibit while app running” remains Phase 3 product work  

## VM validation (optional)

Kinect can be **USB-passed** into the Phase 1 KVM guest for freenect smoke (all three IDs: `02b0` / `02ae` / `02bb`). Proven live depth in guest; not a substitute for tablet bring-up.

## Captures storage

- Writable **`/data`** partition or folder for snaps/AVI when root is locked  

See also `sls-camera` → `hardware/README.md`.

## Removable media stick (test)

Prep a USB for Auto captures / field media tests (destroys stick contents):

```bash
# host — auto-selects single removable USB, or pass /dev/sdX
./scripts/prep-sls-media-usb.sh
# or: sudo ./scripts/prep-sls-media-usb.sh /dev/sda
```

Result: FAT32 label **`SLS-MEDIA`**, folder **`sls-captures/`**.  
See app Captures **Auto** path and [sls-camera#5](https://github.com/tmdrake/sls-camera/issues/5) / [#7](https://github.com/tmdrake/sls-camera/issues/7).
