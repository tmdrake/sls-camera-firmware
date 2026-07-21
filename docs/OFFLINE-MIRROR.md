# Offline mirror (`vendor/`)

## Issue tracking (dependencies & version conflicts)

**Track apt/Python dependency gaps and package version conflicts on the app repo**, not only here:

| Topic | GitHub issue | Status |
|-------|----------------|--------|
| Offline recursive deps + cache install | [sls-camera#2](https://github.com/tmdrake/sls-camera/issues/2) | **Closed** — app has `install-apt-deps.sh` (same rules as below) |
| Version / OR-alternative conflicts (and new ones) | [sls-camera#3](https://github.com/tmdrake/sls-camera/issues/3) | **Open tracker** — comment new finds |

Firmware implements fetch/install scripts; product decisions and installer docs close on **`tmdrake/sls-camera`**. Comment on those issues when a tablet or ISO hits a new conflict.

### App-side handoff (read before field pack day)

**One-pager in the app repo:**  
[`sls-camera/software/linux/docs/FOR-FIRMWARE-TEAM.md`](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FOR-FIRMWARE-TEAM.md)

Same install rules as this document, plus:

```bash
# Prove the app installer against this firmware cache
cd ~/sls-camera
./software/linux/scripts/install-apt-deps.sh \
  --deb-cache ~/sls-camera-firmware/vendor/debs

SLS_OFFLINE=1 ./software/linux/scripts/install-apt-deps.sh \
  --deb-cache ~/sls-camera-firmware/vendor/debs
```

Seed list source of truth for the **app** (keep aligned):  
`sls-camera/software/linux/packages/apt-packages.txt` (includes `espeak-ng` for DrakeVox).

---

Large binaries are **not** stored in git. Regenerate on a connected build host:

```bash
./scripts/10-fetch-offline.sh
```

## Layout

| Path | Contents |
|------|----------|
| `vendor/debs/` | `.deb` files: **seeds** from `packages/apt-packages.txt` **plus recursive hard deps** |
| `vendor/debs/PACKAGE-LIST.txt` | Expanded package names from last fetch (audit) |
| `vendor/wheels/` | Python wheels for `packages/python-requirements.txt` |
| `vendor/models/` | MediaPipe pose landmarker `.task` |
| `vendor/sls-camera/` | Optional full app tree from `20-sync-app.sh` |

### Deb fetch behavior

```bash
./scripts/10-fetch-offline.sh          # seeds + Depends/PreDepends (default)
FETCH_DEPS=0 ./scripts/10-fetch-offline.sh   # seeds only (incomplete offline)
```

Phase 1 on a clean Lubuntu VM showed that seed-only debs left packages unconfigured
(`libjack`, `libavdevice`, `python3-venv` deps, …) until `apt-get -f install` ran online.
Always re-fetch with `FETCH_DEPS=1` before freezing a field pack.

The expander drops **OR-alternative losers** (e.g. `libavcodec-extra*`, `libjack0`).
`install-appliance.sh` does **not** `dpkg -i *.deb` (that fights alternatives). It copies
debs into `/var/cache/apt/archives/` and runs:

```bash
apt-get install -y --no-install-recommends --no-download <seeds>
```

Set `SLS_OFFLINE=1` to refuse network fallback if the cache is incomplete.

### Typical pack size

After recursive fetch on Ubuntu 26.04: on the order of **~350 debs / ~240 MB**
plus wheels + model (total firmware tree often ~700 MB+).

## Why offline

- Field tablets often have **no reliable network**  
- Freezes Ubuntu package versions for a **known-good** freenect + Qt stack  
- Speeds “blow out and reinstall” without re-downloading multi-hundred-MB models  

## What we download (and what we don’t)

| Source | Used for | Notes |
|--------|----------|--------|
| **Ubuntu apt** | freenect, PortAudio, Python, ffmpeg, … | Same packages as a normal `apt install` on the tablet series |
| **PyPI** | numpy, opencv, mediapipe, PySide6, sounddevice, imageio-ffmpeg | Same as `sls-camera` `viewer/requirements.txt` |
| **Google MediaPipe model URL** | `pose_landmarker_lite.task` | Same URL as `viewer/run.sh` |
| **Local fallback** | pose model copy from `~/sls-camera/.../models/` | Preferred when already on the build host |
| **Microsoft Kinect UAC firmware** | — | **Not downloaded** (non-redistributable) |

If `python3 -m pip` is missing on the host, the fetch script uses **`uv`**, the **sls-camera viewer venv**, or bootstraps pip via **get-pip.py** (pypa.io). Prefer:

```bash
sudo apt install -y python3-pip python3-venv
# and/or
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Legal / redistribution

| Item | Public repo | Notes |
|------|-------------|--------|
| Ubuntu packages | OK under their licenses when redistributed carefully | Prefer documenting “run fetch on your mirror host” |
| PyPI wheels | Follow each package license | |
| MediaPipe model | Google terms for the model URL | Same as app `run.sh` |
| **Kinect UAC audio firmware** | **Do not commit** | Microsoft non-redistributable; use `kinect-audio-setup` on-device or a **private** drop outside git |

## Refresh policy

1. Bump package list when app `requirements.txt` changes.  
2. Re-run `10-fetch-offline.sh` on the same Ubuntu series as the tablet (e.g. 24.04).  
3. Update `packages/app-ref.txt` when promoting a new `sls-camera` release.


## App handoff (sls-camera main)

See **[FOR-FIRMWARE-TEAM.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FOR-FIRMWARE-TEAM.md)** for:

- Blow-and-go install resource index (field USB, fetch, install-from-usb)
- **Polkit rule** for Settings → Format removable media (no root password on kiosk)
- Quit exit 10, 16:10 landscape, captures contracts

Detail: [FORMAT-MEDIA-PRIVS.md](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/FORMAT-MEDIA-PRIVS.md)  
Overlay path to ship: `overlay/etc/polkit-1/rules.d/60-sls-udisks-format.rules`
