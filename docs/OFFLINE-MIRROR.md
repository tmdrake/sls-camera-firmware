# Offline mirror (`vendor/`)

Large binaries are **not** stored in git. Regenerate on a connected build host:

```bash
./scripts/10-fetch-offline.sh
```

## Layout

| Path | Contents |
|------|----------|
| `vendor/debs/` | `.deb` files from `packages/apt-packages.txt` |
| `vendor/wheels/` | Python wheels for `packages/python-requirements.txt` |
| `vendor/models/` | MediaPipe pose landmarker `.task` |
| `vendor/sls-camera/` | Optional full app tree from `20-sync-app.sh` |

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
