# Performance expectations & tuning (field tablets)

**Status:** guidance for fleet QA and production polish.  
RCA lab smoke (tablet-01): **boot → SLS app → quit/power-off works**; depth needs correct Kinect **12 V** (see [kinect-portable-power.md](devices/kinect-portable-power.md)).

## Hardware class

| Unit | SoC | RAM | Display (locked) | Reality |
|------|-----|-----|------------------|---------|
| **tablet-01** RCA W101AS23T2 | Atom x5-**Z8350** (Cherry Trail) | **2 GB** | 1280×800 16:10 | Budget slate — usable field UI, not desktop-fast |
| **tablet-02** TMAX TM800W610L | Atom x5-**Z8300** | **2 GB** | 1920×1200 16:10 | Same class; more pixels = slightly more fill cost |
| Phase 1 VM | Host CPU + **llvmpipe** | **Must be 2 GiB / 2 vCPU** for field-like smoke | 1280×800 / 1920×1200 | Worse GPU path than real tablet; do **not** QA TTS on a fat VM |

Cherry Trail is dual/quad low-power Atom (~1.4–1.9 GHz). Expect MediaPipe pose and Qt composite to dominate CPU time.

## What is already accelerated

### Live probe — tablet-01 RCA (2026-07-24, `sls-w101as23t2` / `.226`)

| Item | Measured |
|------|----------|
| SoC GPU | **Intel HD Graphics Cherryview (CHV)** — PCI **8086:22b0** |
| Kernel DRM | **`i915`** → `/dev/dri/card1` + `renderD128` |
| Mesa display / GL | **Gallium `crocus`** (Xorg: `DRI driver: crocus`, AIGLX crocus) |
| Mesa package | **26.0.3** (`libgl1-mesa-dri`, `mesa-libgallium`, …) |
| MediaPipe EGL probe | `GL … renderer: **Mesa Intel(R) HD Graphics (CHV)**` (hardware GL, **not** llvmpipe) |
| MediaPipe inference | Still **`XNNPACK` delegate for CPU** — GL context exists; **pose math is CPU** |
| OpenCV (venv 5.0) | **FFMPEG YES**; **VA: NO**; OpenCL **built YES** but **`haveOpenCL False`** at runtime |
| Record / composite | **CPU** OpenCV MJPEG + numpy — **no VAAPI encode path** |
| App process | Holds FDs on `/dev/dri/card1` (compositor/Qt display); **not** a GPU video encode session |

```text
Kinect USB → freenect (CPU)
  → OpenCV colorize/resize/draw (CPU)
  → MediaPipe pose: EGL/CHV GL may init, inference = XNNPACK CPU
  → OpenCV MJPEG record (CPU)
  → Qt QPixmap blit (display; Mesa crocus for chrome/GL clients)
```

### Summary table

| Subsystem | On RCA lab (measured) | Notes |
|-----------|----------------------|--------|
| **Display / Mesa** | **crocus** + **Intel HD (CHV)** | Real tablet GL — *not* software llvmpipe (VM often llvmpipe) |
| **Depth/IR capture** | freenect over USB | Limited by USB + Kinect **12 V**, not GPU |
| **Pose (MediaPipe)** | **CPU + XNNPACK** | Main cost; Windows SDK skeleton path is different |
| **Record** | OpenCV **MJPEG CPU** @ 1280×720 / 20 fps default | Atom often can’t sustain → wall clock ≫ file duration |
| **VAAPI / NVENC** | **Not used** (VA not in OpenCV build path we ship) | Don’t expect hardware H.264 for SLS AVI today |
| **App target rate** | ~**20 FPS** (`target_fps` / `record_fps`) | Cap to 15 later if needed |

Do not expect CUDA, modern OpenVINO NPU, or high-end VAAPI pipelines on Z83x0. **Having CHV + crocus does not mean pose/record are GPU-accelerated.**

## Symptom → likely cause

| Symptom | Check first |
|---------|-------------|
| UI up, no depth | Kinect **12 V** / legacy charger cutting power; `lsusb` needs **`02ae`** not only `02b0` |
| Slow first open | Font cache / MediaPipe model load — one-time after install |
| Jank + low RAM | 2 GB pressure; desktop chrome still present (see [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md)) |
| Hot / throttle | Fanless Atom under continuous pose — normal; reduce load or improve ventilation |
| VM feels worse than tablet | SPICE + llvmpipe; tablet GL is the real path |
| VM feels *better* than tablet (TTS fine, field not) | Guest has too much RAM/CPU — pin **2 GiB / 2 vCPU** ([VM-REBUILD.md](VM-REBUILD.md) tablet-class) |

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
- [VM-REBUILD.md](VM-REBUILD.md) — **tablet-class 2 GiB / 2 vCPU** + DrakeVox TTS smoke  
- [devices/kinect-portable-power.md](devices/kinect-portable-power.md) — 12 V / motor-only USB  
- App issue [sls-camera#13](https://github.com/tmdrake/sls-camera/issues/13) — TTS latency under load
- [devices/rca-w101as23t2.md](devices/rca-w101as23t2.md) — tablet-01  
- App viewer: `config.target_fps`, `pose.py` (MediaPipe), freenect capture thread  

## Open / later

- [ ] Measure and record steady FPS + load on tablet-01/02 for HARDWARE-MATRIX  
- [ ] Optional appliance zram in `install-appliance.sh`  
- [ ] Residual **EFI** issues (wrong device, USB probe) — primary 30s delay was GRUB `recordfail` (see [EFI-BOOT.md](EFI-BOOT.md))
