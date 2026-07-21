# Performance expectations & tuning (field tablets)

**Status:** guidance for fleet QA and production polish.  
RCA lab smoke (tablet-01): **boot → SLS app → quit/power-off works**; depth needs correct Kinect **12 V** (see [kinect-portable-power.md](devices/kinect-portable-power.md)).

## Hardware class

| Unit | SoC | RAM | Display (locked) | Reality |
|------|-----|-----|------------------|---------|
| **tablet-01** RCA W101AS23T2 | Atom x5-**Z8350** (Cherry Trail) | **2 GB** | 1280×800 16:10 | Budget slate — usable field UI, not desktop-fast |
| **tablet-02** TMAX TM800W610L | Atom x5-**Z8300** | **2 GB** | 1920×1200 16:10 | Same class; more pixels = slightly more fill cost |
| Phase 1 VM | Host CPU + **llvmpipe** | VM RAM | 1280×800 / 1920×1200 | Worse GPU path than real tablet |

Cherry Trail is dual/quad low-power Atom (~1.4–1.9 GHz). Expect MediaPipe pose and Qt composite to dominate CPU time.

## What is already accelerated

| Subsystem | Typical on RCA lab | Notes |
|-----------|-------------------|--------|
| **Qt / OpenGL ES** | Mesa **Intel HD Graphics (CHV)** | Real tablet GL — *not* software llvmpipe (VM uses llvmpipe) |
| **Depth/IR capture** | freenect over USB | Limited by USB + Kinect power, not GPU |
| **Pose (MediaPipe)** | **CPU + XNNPACK** | Main cost; **not** in Kinect/freenect API (Windows SDK had skeleton in-runtime — app team follow-up in `sls-camera` TODO) |
| **App target rate** | ~**20 FPS** (`target_fps` in viewer config) | Composite / record path; pose may not hit every frame on 2 GB |

Do not expect CUDA, modern OpenVINO NPU, or high-end VAAPI pipelines on Z83x0.

## Symptom → likely cause

| Symptom | Check first |
|---------|-------------|
| UI up, no depth | Kinect **12 V** / legacy charger cutting power; `lsusb` needs **`02ae`** not only `02b0` |
| Slow first open | Font cache / MediaPipe model load — one-time after install |
| Jank + low RAM | 2 GB pressure; desktop chrome still present (see [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md)) |
| Hot / throttle | Fanless Atom under continuous pose — normal; reduce load or improve ventilation |
| VM feels worse than tablet | SPICE + llvmpipe; tablet GL is the real path |

## Tuning (no hardware change)

### App Settings (operator)

- **Max people = 1** (MediaPipe default; multi-person is expensive).  
- Avoid very low confidence (more false work).  
- Spectrum styles: heavier looks cost a little; Phosphor is fine for field.

### System (firmware / tech)

```bash
# RAM pressure — zram if not present (lab / appliance harden)
free -h
# CPU governor (may need root; thermal limits still apply)
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# optional lab test: performance (not always available / may heat)
# echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

- Prefer **direct USB** for Kinect; avoid deep unpowered hub chains.  
- Strip desktop chrome when Phase 3 kiosk lands (frees RAM/CPU).  
- Keep **one** autologin user `sls`; no extra desktop sessions.

### App / firmware backlog (software)

- Pose every Nth frame / lower internal landmarker input size (“field lite” mode).  
- Ensure compositor isn’t software-falling-back (`glxinfo` / EGL logs at start).  
- Optional: document measured FPS line in geometry/status for #7 matrix rows.

## Fleet upgrade path (better CPU)

When BOM allows a step up from Cherry Trail:

| Prefer | Why |
|--------|-----|
| **Intel N100 / N305** (or similar modern N-series) tablet or mini-PC | Much better multi-thread efficiency |
| **≥8 GB RAM** | Qt + MediaPipe + captures headroom |
| Still **16:10 landscape** glass if possible | Matches Settings layout work |
| Same Kinect + **operate-mode 12 V** portable pack | Unchanged sensor story |

Software path stays: Lubuntu 26.04 amd64 + freenect + offline field USB.

## What will *not* magically fix Z8350

- Turning on random “GPU pose” flags without testing (often slower or unsupported).  
- Higher SPICE/VM resolution for lab (doesn’t model tablet CPU).  
- Leaving SLS-MEDIA stick inserted (unrelated to FPS).  
- Charger path that **disables Kinect 12 V** (no depth at all).

## Related

- [HARDWARE.md](HARDWARE.md) — fleet table  
- [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md) — less chrome → more headroom  
- [devices/kinect-portable-power.md](devices/kinect-portable-power.md) — 12 V / motor-only USB  
- [devices/rca-w101as23t2.md](devices/rca-w101as23t2.md) — tablet-01  
- App viewer: `config.target_fps`, `pose.py` (MediaPipe), freenect capture thread  

## Open / later

- [ ] Measure and record steady FPS + load on tablet-01/02 for HARDWARE-MATRIX  
- [ ] Optional appliance zram in `install-appliance.sh`  
- [ ] Residual **EFI** issues (wrong device, USB probe) — primary 30s delay was GRUB `recordfail` (see [EFI-BOOT.md](EFI-BOOT.md))
