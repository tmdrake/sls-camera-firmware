# Screenshots (Phase 1 appliance VM)

**Canonical path:** `docs/images/`  
**Shortcut:** repo root `screenshots` → this directory (symlink).

Captured from KVM guest **`sls-appliance-phase1`** (Lubuntu **26.04**, appliance install) on the build host via:

```bash
virsh -c qemu:///system screenshot sls-appliance-phase1 /path/to/out.png
# virsh may write PNG bytes even with a .ppm/.raw suffix — check `file` and rename to .png
```

App shots:

```bash
# on guest, as sls, with session X11 env
DISPLAY=:0 /opt/sls-camera/software/linux/viewer/run.sh --demo
# or: DISPLAY=:0 /usr/local/bin/sls-camera --demo
# live Kinect: host ./scripts/vm-kinect-usb.sh reattach then sls-camera (no --demo)
```

| File | Description |
|------|-------------|
| [01-guest-desktop.png](01-guest-desktop.png) | Lubuntu 26.04 desktop after first boot (LXQt) |
| [02-sls-demo-app.png](02-sls-demo-app.png) | SLS Camera Qt UI (earlier pin) — demo depth/SLS, IR PiP, DrakeVox, spectrum |
| [03-sls-demo-hud.png](03-sls-demo-hud.png) | Same earlier session (HUD / FPS) |
| [05-kinect-passthrough.png](05-kinect-passthrough.png) | **Live Kinect** via USB passthrough (depth + IR) |
| [06-sls-user-session.png](06-sls-user-session.png) | User session / desktop chrome note |
| [10-phase1-demo-main.png](10-phase1-demo-main.png) | **2026-07-22** Phase 1 demo — main UI (status bar, conf 25%, spectrum) |
| [11-phase1-demo-hud.png](11-phase1-demo-hud.png) | Same session ~seconds later (HUD timestamp) |
| [13-phase1-demo-settled.png](13-phase1-demo-settled.png) | Settled demo frame under tablet-class VM (2 GiB / CPU-capped) |
| [20-phase1-kinect-live.png](20-phase1-kinect-live.png) | **2026-07-22** Phase 1 **live Kinect** — depth+SLS, IR PiP, status **Live** |
| [21-phase1-kinect-settled.png](21-phase1-kinect-settled.png) | Same session settled frame (real room geometry, not --demo) |
| [20260722-screen.jpg](20260722-screen.jpg) | **2026-07-22** lab capture |
| [20260722-settings.jpg](20260722-settings.jpg) | **2026-07-22** Settings capture |

**Guest resources for 10–13:** tablet-class **2 GiB** — [VM-REBUILD.md](../VM-REBUILD.md).

Do not commit Microsoft Kinect firmware blobs; these images are UI-only.

### Live Kinect (20–21)

```bash
# host
./scripts/vm-kinect-usb.sh reattach
# guest
lsusb | grep 045e
/usr/local/bin/sls-camera   # no --demo
# host
virsh -c qemu:///system screenshot sls-appliance-phase1 docs/images/out.png
```

Isochronous USB can glitch under SPICE; bare metal remains field truth. See [POWER-AND-DISPLAY.md](../POWER-AND-DISPLAY.md).
