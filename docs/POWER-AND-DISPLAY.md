# Power management & display policy (appliance)

Field goal: the tablet does **not** rotate, sleep, or fight the operator during an investigation. The SLS app owns **brightness** (Settings).

Issue tracking for packaging deps stays on **sls-camera** ([#2](https://github.com/tmdrake/sls-camera/issues/2) / [#3](https://github.com/tmdrake/sls-camera/issues/3)). This doc is firmware/session policy.

## Display

| Concern | Policy | Notes |
|---------|--------|--------|
| **Brightness** | **App controls it** (Settings ±10%) | Uses sysfs backlight, `brightnessctl`, or `xrandr` fallback — see `sls-camera` `backlight.py` |
| **Auto-rotate** | **Disable** on field tablets | Avoid portrait flip mid-investigation |
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

### Disable rotation (LXQt / X11 — validate in VM or tablet)

```bash
# Session-level: turn off monitor rotation sensors if present
gsettings set org.gnome.settings-daemon.plugins.orientation active false 2>/dev/null || true

# X11: force landscape (example output name from xrandr)
# xrandr --output eDP-1 --rotate normal

# iio-sensor-proxy: stop auto-rotate service on appliance images
sudo systemctl disable --now iio-sensor-proxy.service 2>/dev/null || true
```

Overlay path (future Phase 1 harden): drop a small script or systemd unit under `overlay/` that runs for user `sls`.

### Disable idle blank / suspend (session)

```bash
# LXQt session (typical Lubuntu)
# Power management → sleep/suspend: never on AC; prefer never on battery for field kits with brick.

# X11 DPMS off for current session
xset s off
xset -dpkg 2>/dev/null || true
xset s noblank
xset -dpms

# systemd logind (system-wide appliance)
# /etc/systemd/logind.conf.d/sls-no-suspend.conf
# [Login]
# HandleLidSwitch=ignore
# HandleSuspendKey=ignore
# IdleAction=ignore
```

Example drop-in for firmware overlay:

```ini
# overlay/etc/systemd/logind.conf.d/50-sls-no-suspend.conf
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
IdleAction=ignore
```

App-side **inhibit suspend while running** remains Phase 3 product work (`sls-camera` backlog).

### Quit → power off

Firmware launcher (`overlay/usr/local/bin/sls-camera`) sets **`SLS_ON_QUIT=shutdown`** by default: after the operator confirms **Quit** in the app, the host powers off (`loginctl poweroff` / `systemctl poweroff` / passwordless `sudo poweroff` via `etc/sudoers.d/sls-poweroff`).

Use `SLS_ON_QUIT=none` on a lab VM if you want Quit to return to the desktop without powering off.

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
