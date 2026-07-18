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
