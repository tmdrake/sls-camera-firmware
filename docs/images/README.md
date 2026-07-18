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

**Date:** 2026-07-17 · **Guest:** Ubuntu/Lubuntu 26.04 · **Mode:** `--demo` (status bar shows `demo mode (no kinect)`)

Do not commit Microsoft Kinect firmware blobs; these images are UI-only.
