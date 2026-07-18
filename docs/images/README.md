# Screenshots (Phase 1 appliance VM)

Captured from KVM guest **`sls-appliance-phase1`** (Lubuntu **26.04**, `install-appliance.sh` applied) on the build host via:

```bash
virsh -c qemu:///system screenshot sls-appliance-phase1 /path/to/out.png
```

App shots use the system launcher in **demo** mode (no Kinect in the VM):

```bash
DISPLAY=:0 /usr/local/bin/sls-camera --demo
```

| File | Description |
|------|-------------|
| [01-guest-desktop.png](01-guest-desktop.png) | Lubuntu 26.04 desktop after first boot (LXQt) |
| [02-sls-demo-app.png](02-sls-demo-app.png) | SLS Camera Qt UI — demo depth/SLS, IR PiP, DrakeVox, spectrum, HUD |
| [03-sls-demo-hud.png](03-sls-demo-hud.png) | Same session a few seconds later (HUD timestamp / FPS) |
| [05-kinect-passthrough.png](05-kinect-passthrough.png) | **Live Kinect** via USB passthrough into the VM (depth + IR + status `live · 640x480`) |

**Date:** 2026-07-17 · **Guest:** Ubuntu/Lubuntu 26.04

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
