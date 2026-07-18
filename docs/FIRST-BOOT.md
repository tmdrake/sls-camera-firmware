# First boot (appliance)

## Lab VM credentials (rebuild standard)

| User | Password | Purpose |
|------|----------|---------|
| **`sls`** | **`20260717`** | Appliance autologin, SSH, field app session (**use this**) |

Lab-only — change on real tablets. Full rebuild procedure: **[VM-REBUILD.md](VM-REBUILD.md)**.

## Phase 1 (install-appliance.sh)

After install on a blank Ubuntu/Lubuntu system:

1. Reboot  
2. Auto-login as user **`sls`** (SDDM on Lubuntu 26.04; also LightDM/GDM when present)  
3. Autostart launches **`/usr/local/bin/sls-camera`** when logged in as `sls`  
4. SLS app opens fullscreen  

If a temporary ISO install user still exists (e.g. leftover desktop scrap), remove it and keep only **`sls`** — see [VM-REBUILD.md](VM-REBUILD.md).

Without a Kinect (VM smoke test), run:

```bash
/usr/local/bin/sls-camera --demo
```

### Quit → power off (appliance)

The firmware launcher `/usr/local/bin/sls-camera` defaults to **shutting down the machine** when the operator confirms Quit (button / Q / window close). That keeps a field tablet from dropping to a bare desktop.

| `SLS_ON_QUIT` | Behavior |
|---------------|----------|
| `shutdown` (default) | Power off after app exits |
| `restart` | Relaunch the app (kiosk loop) |
| `none` | Exit to desktop only |

Examples:

```bash
# temporary: quit stays on desktop
SLS_ON_QUIT=none /usr/local/bin/sls-camera

# permanent for a session user: put in ~/.config/environment.d/sls.conf or autostart
# SLS_ON_QUIT=restart
```

Lab VM credentials: **`sls` / `20260717`** — see [VM-REBUILD.md](VM-REBUILD.md).

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
