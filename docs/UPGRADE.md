# Field upgrade / auto-upgrade (roadmap)

**Today:** refresh an appliance by re-running **SLS-MEDIA** install (no OS wipe required).  
**Later:** first-class upgrade channel so tablets pick up app + overlay without a full stick ceremony.

## What works now (manual upgrade)

On a tablet that already has Lubuntu + an older SLS appliance:

1. Plug current **SLS-MEDIA** stick (built with `scripts/50-build-field-usb.sh`).  
2. Run **`install-from-usb.sh`** (same as first appliance install).  
3. Prefer **cold power cycle** on RCA after install.  
4. Smoke: app autostart, speakers, Kinect, Quit→poweroff.

`install-appliance.sh` is **idempotent enough** for lab: re-rsyncs `/opt/sls-camera`, rebuilds venv from wheels, reinstalls overlay (launcher, SST on bare metal, sudoers, GRUB recordfail, etc.).

| Method | Wipes OS? | Use when |
|--------|-----------|----------|
| `install-from-usb.sh` again | No | Day-to-day field refresh |
| Wipe + Lubuntu + stick | Yes | Corrupt root, OS upgrade, clean ship |
| Stage B single ISO | Yes (image) | Future factory image |

Pin check after upgrade:

```bash
# on tablet
head -5 /opt/sls-camera/README.md 2>/dev/null
/usr/local/bin/sls-camera --help 2>&1 | head -3
test -f /etc/modprobe.d/sls-audio-sst.conf && echo "RCA SST present" || echo "no SST (VM or skipped)"
```

## Desired later (not built yet)

| Piece | Intent |
|-------|--------|
| **Version stamp** | `/etc/sls/appliance-version` (firmware git + app pin) written by install |
| **Upgrade stick / pack** | Same SLS-MEDIA layout; optional `upgrade-from-usb.sh` that only refreshes app+overlay if newer |
| **Channel / OTA (optional)** | Signed tarball or apt repo for online lab units — **not** default field (offline-first) |
| **Auto-upgrade policy** | Off by default; lab may enable “check stick on mount” or timed pull |
| **Rollback** | Keep previous `/opt/sls-camera.bak` or A/B app dir for one reboot |

Track: [TODO.md](TODO.md) Phase 3 / backlog · product: offline-first still wins over always-on OTA.

## Design constraints

1. **Hardware-first** — upgrade path must re-apply RCA SST / speakers / PMIC on bare metal; never force SST on KVM.  
2. **Offline** — field units may have no Wi‑Fi; stick remains primary.  
3. **No silent full wipe** — auto-upgrade must not reformat eMMC.  
4. **App pin** — `packages/app-ref.txt` remains source of truth for what the stick ships.

## Interim operator habit

```text
Host:  APP_SRC=~/sls-camera ./scripts/20-sync-app.sh
       ./scripts/50-build-field-usb.sh /run/media/$USER/SLS-MEDIA
Tablet: bash install-from-usb.sh → cold cycle → smoke
```

Until auto-upgrade exists, **rebuilt stick + re-run install** is the upgrade path.
