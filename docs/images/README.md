# Screenshots (Phase 1 appliance VM)

Captured from KVM guest **`sls-appliance-phase1`** (Lubuntu **26.04**, appliance install) on the build host via:

```bash
virsh -c qemu:///system screenshot sls-appliance-phase1 /path/to/out.png
# virsh may write PNG bytes even with a .ppm/.raw suffix — check `file` and rename to .png
```

App shots use the viewer in **demo** mode (no Kinect in the VM unless USB-passthrough):

```bash
# on guest, as sls, with session X11 env
DISPLAY=:0 /opt/sls-camera/software/linux/viewer/run.sh --demo
# or: DISPLAY=:0 /usr/local/bin/sls-camera --demo
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

**Guest resources for 10–13:** tablet-class **2 GiB** + meaner `vcpu_quota` (see [VM-REBUILD.md](../VM-REBUILD.md)). App pin: post-#13 TTS / UI updates.

Do not commit Microsoft Kinect firmware blobs; these images are UI-only.

### USB passthrough (host → guest)

Host must see all three NUI devices, then:

```bash
# attach (live)
for id in 02b0 02ae 02bb; do
  cat >/tmp/k.xml <<EOF
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source><vendor id='0x045e'/><product id='0x$id'/></source>
</hostdev>
EOF
  virsh -c qemu:///system attach-device sls-appliance-phase1 /tmp/k.xml --live
done

# in guest: lsusb | grep 045e ; /usr/local/bin/sls-camera
# detach when finished (return Kinect to host)
virsh -c qemu:///system detach-device sls-appliance-phase1 /tmp/k.xml --live  # per device
```

Isochronous USB can glitch under SPICE/VMs; bare metal remains the field truth. See [POWER-AND-DISPLAY.md](../POWER-AND-DISPLAY.md).
