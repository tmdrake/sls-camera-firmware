# First boot (appliance)

## Phase 1 (install-appliance.sh)

After install on a blank Ubuntu/Lubuntu system:

1. Reboot  
2. Auto-login as user **`sls`** (if LightDM/GDM config applied; **Lubuntu 26.04 uses SDDM** — autologin may need a separate SDDM config)  
3. Autostart launches **`/usr/local/bin/sls-camera`** when logged in as `sls`  
4. SLS app opens fullscreen  

Without a Kinect (VM smoke test), run:

```bash
/usr/local/bin/sls-camera --demo
```

### Screenshots (Phase 1 VM — Lubuntu 26.04)

Full-size PNGs live in [`docs/images/`](images/README.md).

| | |
|--|--|
| Desktop after install | ![Lubuntu desktop](images/01-guest-desktop.png) |
| SLS Camera `--demo` | ![SLS demo UI](images/02-sls-demo-app.png) |

Operator should only need:

- Kinect **power brick** + USB  
- (Optional) audio: `kinect-audio-setup` once if spectrum/record mic required  

## Captures

- Preferred: `/data/sls-captures`  
- Launcher exports `SLS_CAPTURES_DIR` when that directory exists  

## Failure modes

| Symptom | Check |
|---------|--------|
| Black screen / no app | `journalctl -b`, autostart desktop file, `DISPLAY` |
| freenect BUSY | `lsmod \| grep gspca`; blacklist applied? |
| Spectrum silent | `libportaudio2`, Kinect USB Audio after firmware |

## Factory reset (Phase 3)

Re-run `install-appliance.sh` or reflash ISO; wipe `/data` only if operator confirms investigation media can be discarded.
