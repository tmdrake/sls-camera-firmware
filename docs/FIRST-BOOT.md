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

### Quit / power off (respects app request)

The launcher **`/usr/local/bin/sls-camera`** prefers the **app’s exit code** (product contract for [sls-camera#4](https://github.com/tmdrake/sls-camera/issues/4)):

| Exit code | Meaning | Launcher action |
|-----------|---------|-----------------|
| **0** | Clean quit | See `SLS_QUIT_FALLBACK` (appliance default: **power off** until the app sends `10`) |
| **10** | Operator requested **host power-off** | Power off |
| **11** | Relaunch app | Restart launcher |
| other | Error / crash | Exit (no power off); optional `SLS_QUIT_ON_ERROR=restart` |

| Env | Values | Role |
|-----|--------|------|
| `SLS_ON_QUIT` | `app` (default), `shutdown`, `restart`, `none` | `app` = honor codes; `shutdown` = any exit powers off (legacy) |
| `SLS_QUIT_FALLBACK` | `shutdown` (default on appliance), `none`, `restart` | Used when exit is **0** under `SLS_ON_QUIT=app` |

Examples:

```bash
# Lab: Quit returns to desktop (even while app still exits 0)
SLS_ON_QUIT=app SLS_QUIT_FALLBACK=none /usr/local/bin/sls-camera

# After sls-camera implements exit 10 on “Power off”:
#   SLS_ON_QUIT=app SLS_QUIT_FALLBACK=none   # only power off when app asks
```

Lab VM credentials: **`sls` / `20260717`** — see [VM-REBUILD.md](VM-REBUILD.md).

Launcher debug log (guest): `/data/sls-captures/launcher.log` (or `/tmp/sls-camera-launcher.log`).

### Login screen once instead of autologin

SDDM can drop to the greeter if the session **crashes** or is torn down mid-boot. With **`Relogin=true`**, the next attempt should autologin again as `sls`. Check:

```bash
journalctl -u sddm -b
# look for: sddm-helper crashed / Authentication error
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
