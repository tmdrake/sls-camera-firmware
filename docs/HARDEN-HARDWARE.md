# Harden: disable unused OS hardware / services

**Phase 3** — cut boot noise, RAM, and error spam on field tablets.  
Field SLS needs: **display, touch, USB (Kinect), audio path for spectrum, optional Ethernet/Wi‑Fi for lab SSH**. Almost everything else can go.

Track: [TODO.md](TODO.md) · [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md) · [PERFORMANCE.md](PERFORMANCE.md).

## Goal

```text
Fewer failed probes in journalctl → cleaner boot, slightly less load on 2 GB SoCs
```

Disable or mask **services and modules we do not use**, not “break Kinect.”

**This is not “remove the Lubuntu desktop.”** LXQt stays; the SLS app runs fullscreen on top. Stripping panel/wallpaper/file manager is a separate track — [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md) Phase 3.

## Errors seen on tablet-01 RCA (lab) — map to action

| Journal / symptom | Needed for SLS? | Harden action |
|-------------------|-----------------|---------------|
| `sof-audio-acpi-intel-byt` no ASoC machine | **RCA speakers needed** | Do **not** only ignore — force **SST** + Speaker path on RCA; see [rca-w101as23t2.md](devices/rca-w101as23t2.md#rca-speaker-fix-full-stack-lab-validated-2026-07). Kinect mic remains USB UAC. |
| `bluetoothd` / Failed to set mode | **No** field | **mask** `bluetooth.service` |
| `ModemManager` | **No** (no WWAN) | **mask** `ModemManager.service` |
| `thermald` No Zones | No useful thermal on this ACPI | **disable** thermald if present |
| `obexd` / evolution-source-registry | **No** | comes with BT; dies with bluetooth off |
| `cups` / print | **No** | **mask** cups / cups-browsed |
| `avahi-daemon` | No field | **disable** (lab mDNS optional) |
| `fwupd` / firmware updater | No kiosk | **disable** timers/service |
| `apport` / `whoopsie` crash reporters | No | **disable** |
| `spice-vdagent` | **VM only** | disable on bare metal (harmless if missing) |
| `colord` EDID warnings | No | ignore or disable colord if easy |
| `r8723bs` staging Wi‑Fi warning | Lab net only | keep if you need Wi‑Fi; else leave |
| Goodix I2C / dummy regulators | **Yes touch** | do **not** disable; see [TOUCH-GOODIX.md](TOUCH-GOODIX.md) |
| Kinect / freenect | **Yes** | never blacklist freenect; gspca_kinect already blacklisted |

## Already applied by appliance install

| Item | How |
|------|-----|
| Auto updates / packagekit | disabled/masked |
| LXQt power / update autostart | Hidden |
| iio-sensor-proxy (auto-rotate) | masked |
| gspca_kinect | modprobe blacklist |
| logind suspend | ignore |
| USB/SD **AutoRun popup** | pcmanfm-qt `AutoRun=false` (mount kept on) — [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md) |

## Implement (script)

`overlay/usr/local/bin/sls-disable-unused-hw` + call from `install-appliance.sh`:

- Mask/disable: Bluetooth, ModemManager, CUPS, apport, whoopsie, fwupd refresh, avahi (optional flag)
- Config: `/etc/sls/harden-hw.conf` — `KEEP_BLUETOOTH=0`, `KEEP_AVAHI=0`, `KEEP_CUPS=0`
- Log actions to `/data/sls-captures/harden-hw.log` when `/data` exists

**Do not** disable NetworkManager by default (lab SSH / charge idle still useful).

## Lab vs field

| Profile | Keep | Drop |
|---------|------|------|
| **Field** | NM (optional), USB, sound for Kinect UAC | BT, modem, print, crash report, fwupd |
| **Lab debug** | NM, maybe avahi, SSH | Same hardware junk; may leave BT off |

## Verify after harden

```bash
systemctl is-enabled bluetooth ModemManager cups 2>/dev/null
journalctl -b -p err --no-pager | head -40
# Kinect still:
lsusb | grep 045e
```

## Related RCA noise (not “disable hardware”)

- Wake on AC plug — EC; [rca-w101as23t2.md](devices/rca-w101as23t2.md)  
- Charge-idle poweroff — [CHARGE-IDLE-POWEROFF.md](CHARGE-IDLE-POWEROFF.md)  
