# Power management & display policy (appliance)

Field goal: the tablet does **not** rotate, sleep, or fight the operator during an investigation. The SLS app owns **brightness** (Settings).

Issue tracking for packaging deps stays on **sls-camera** ([#2](https://github.com/tmdrake/sls-camera/issues/2) / [#3](https://github.com/tmdrake/sls-camera/issues/3)). This doc is firmware/session policy.

## Display

| Concern | Policy | Notes |
|---------|--------|--------|
| **Brightness** | **App controls it** (Settings ±10%) | Uses sysfs backlight, `brightnessctl`, or `xrandr` fallback — see `sls-camera` `backlight.py` |
| **Orientation** | **Locked landscape** on all field tablets | Native glass may be portrait; firmware forces width ≥ height |
| **Auto-rotate** | **Disabled** (`iio-sensor-proxy` masked) | No portrait flip mid-investigation |
| **Screen blank / DPMS** | **Disable or very long** while session is kiosk/field | Prevent black screen during idle |
| **Lock screen** | **Disable** for appliance user `sls` | No password gate on reboot kiosk path |
| **Power management popups** | **Disable** LXQt power manager idle/lid/battery watchers | Overlay hides `lxqt-powermanagement` autostart |
| **Update notifications** | **Disable** unattended-upgrades + Lubuntu update notifier | No “updates available” during investigations |

### Quiet updates (no popups)

Installed by `install-appliance.sh` from `overlay/`:

| Path | Effect |
|------|--------|
| `etc/apt/apt.conf.d/99sls-disable-auto-upgrades` | APT periodic = 0 |
| `systemctl disable/mask` apt-daily, unattended-upgrades, packagekit | No background upgrade agents |
| `etc/xdg/autostart/lubuntu-update-autostart.desktop` | `Hidden=true` |
| `etc/xdg/autostart/lxqt-powermanagement.desktop` | `Hidden=true` |
| `home/sls/.config/lxqt/lxqt-powermanagement.conf` | All watchers off |

Field tablets can still be updated **manually** by a tech (`apt update && apt upgrade`) when planned.

### Landscape lock (tablet-01, tablet-02, fleet default)

Both fleet tablets ship with **portrait-native** panels under Windows:

| Unit | Windows msinfo | Appliance target (landscape) |
|------|----------------|------------------------------|
| **tablet-01** RCA W101AS23T2 | 800×1280 | **1280×800** |
| **tablet-02** TMAX TM800W610L | 1200×1920 | **1920×1200** |

Installed by `install-appliance.sh` from `overlay/`:

| Piece | Role |
|-------|------|
| `/usr/local/bin/sls-lock-landscape` | If height > width: `xrandr --rotate **right**` (fleet default; then `left` if still portrait) |
| same script | Touch: `xinput map-to-output` + **Coordinate Transformation Matrix** for that rotation |
| `etc/xdg/autostart/sls-lock-landscape.desktop` | Runs at LXQt login for user `sls` |
| `sls-camera` launcher | Re-runs lock immediately before starting the app |
| `systemctl mask iio-sensor-proxy` | Stops accelerometer auto-rotate from undoing landscape |

| Env | Default | Role |
|-----|---------|------|
| `SLS_LANDSCAPE_ROTATE` | **`right`** | Preferred RandR rotate (live + fleet notes) |
| `SLS_SKIP_TOUCH_MAP` | `0` | Set `1` to skip touch remap |

```bash
# Manual check (guest, live, or tablet X11)
export SLS_LANDSCAPE_ROTATE=right   # fleet default
/usr/local/bin/sls-lock-landscape
xrandr | awk '/ connected/{print}'
# expect width >= height; touch drag should match screen axes
```

**Touch:** Goodix / i2c-hid on Cherry Trail often **does not** follow RandR alone. The lock script sets CTM for `right` (`0 1 0 -1 0 1 0 0 1`) and `map-to-output`. If axes are still wrong, try `SLS_LANDSCAPE_ROTATE=left` and file a note on [#7](https://github.com/tmdrake/sls-camera/issues/7).

Live session Wi‑Fi / SSH (lab): [LIVE-SESSION.md](LIVE-SESSION.md).

### Disable idle blank / suspend (session)

Appliance install ships:

| Piece | Role |
|-------|------|
| `logind` `50-sls-no-suspend.conf` | Ignore lid / suspend keys / idle action |
| LXQt power manager | Autostart **hidden** |
| `/usr/local/bin/sls-disable-dpms` + xdg autostart | `xset s off`, `-dpms` at login |
| `/usr/local/bin/sls-lock-landscape` + xdg autostart | Force landscape; see section above |
| `sls-camera` launcher | Re-applies landscape lock + `xset` before starting the app |

```bash
# Manual session fix (guest or tablet X11)
xset s off
xset s noblank
xset -dpms
```

**App gap (dev should implement):** while the field UI is running, call ScreenSaver / logind **Inhibit** so idle blanking cannot return after 10 minutes without touch. Tracked: [sls-camera#9](https://github.com/tmdrake/sls-camera/issues/9).

**VM flicker note:** host monitor power-save (e.g. GNOME idle 5 min) can blank the **physical** display while virt-viewer is open even if the guest app is active — SPICE may not count as user activity. Check host power settings too.

### Quit → power off (app-driven)

Firmware launcher (`overlay/usr/local/bin/sls-camera`) **respects app exit codes** ([sls-camera#4](https://github.com/tmdrake/sls-camera/issues/4)):

| Code | App intent | Launcher |
|------|------------|----------|
| `10` | Power off host | `loginctl` / `systemctl` / `sudo poweroff` (`etc/sudoers.d/sls-poweroff`) |
| `11` | Relaunch | re-exec launcher |
| `0` | Clean quit | `SLS_QUIT_FALLBACK` (appliance default `shutdown` until app emits `10`) |

Defaults (post app pin **59ebee6** / sls-camera#4):

- `SLS_QUIT_ACTION=shutdown` — app confirms “Power off?” and exits **10**
- `SLS_ON_QUIT=app` — launcher honors exit codes  
- `SLS_QUIT_FALLBACK=none` — exit **0** does not power off  

Lab without poweroff: `SLS_QUIT_ACTION=exit /usr/local/bin/sls-camera`.

## Brightness ownership

1. Operator uses **SLS Settings → Brightness**, not the desktop brightness applet.  
2. Appliance images should avoid a second auto-brightness daemon fighting sysfs.  
3. If both desktop and app adjust backlight, last writer wins — prefer killing/hiding desktop brightness applets on kiosk chrome cleanup.

## USB / Kinect in a VM (validation only)

Real field units use native USB. For **KVM** bring-up:

1. Plug Kinect + power brick on the **host**.  
2. Confirm host sees: `045e:02b0` (motor), `045e:02ae` (camera), `045e:02bb` (audio).  
3. Pass all three into the guest (`virsh attach-device` hostdev, `managed='yes'`).  
4. In guest: `lsusb`, then `/usr/local/bin/sls-camera` (not only `--demo`).  
5. Detach when done so the host can use the Kinect again.

USB passthrough is flaky vs bare metal (isochronous depth streams, hubs). **Tablet/host install is the truth**; VM is a packaging + best-effort freenect smoke.

## Related

- `docs/HARDWARE.md` — Kinect BOM  
- `docs/FIRST-BOOT.md` — after appliance install  
- App: Settings brightness, reconnect, battery indicator  
