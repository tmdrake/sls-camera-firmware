# Live-build / chroot hooks (Phase 2)

Scripts here will run inside the target rootfs during ISO generation:

| Hook | Purpose |
|------|---------|
| `01-install-offline-debs.sh` | `dpkg -i` vendor debs |
| `02-install-python-venv.sh` | Create `/opt/sls-camera` venv from wheels |
| `03-autologin-kiosk.sh` | Configure DM + strip desktop chrome |
| `04-writable-data.sh` | Ensure `/data/sls-captures` |

Not executed in Phase 0–1; `install-appliance.sh` covers the same concerns on a live system.
