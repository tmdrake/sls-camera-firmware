# Charge-idle power off (unattended charge)

## Why

| Unit | Charge path | Kinect while charging? | Wanted behavior |
|------|-------------|------------------------|-----------------|
| **tablet-01 RCA** | Dedicated **5 V** jack (detected charger) | **No** — charge path conflicts with Kinect 12 V / field pack | Plug AC → unit may **power on** (EC) → after **15 min** of charging, **power off** so battery fills |
| **tablet-02 TMAX** | **OTG** via control circuit (**OTG port required**) | **Yes** — run while powered from that path | Set **`ENABLED=0`** so the unit does **not** auto-shutdown while on OTG power |

**Lab validated (RCA, 2026-07-21):** with `axp288_charger online=1` / status Charging, service accumulated 15 min and powered off as intended.

Also covers: charger wakes tablet; leave brick plugged overnight without a full desktop session for hours.

## Detection (best-effort)

Linux on AXP288 (RCA) often lies (`online=0`, status still `Discharging`). The helper treats any of these as **charging**:

1. `power_supply` type Mains/USB with **`online=1`**  
2. Battery **`status`** = `Charging`, `Full`, or `Not charging`  
3. Battery **`current_now` > +50 mA** (µA units in sysfs)  
4. Optional: **capacity % rising** between polls (`CAPACITY_TREND=1`)

If none of these ever trip, the service **will not** power off (safe default when status is wrong).

## Config

**`/etc/sls/charge-idle.conf`** (installed from overlay):

```bash
ENABLED=1          # 0 on OTG-run tablets (TMAX control-circuit charge)
IDLE_MINUTES=15
POLL_SEC=30
CAPACITY_TREND=1
```

Env overrides: `SLS_CHARGE_IDLE_ENABLED`, `SLS_CHARGE_IDLE_MINUTES`.

## Service

```bash
systemctl status sls-charge-idle-poweroff
journalctl -u sls-charge-idle-poweroff -b
tail -f /data/sls-captures/charge-idle.log
```

Installed and **enabled** by `install-appliance.sh`.

## Operator notes

- **RCA:** leave dedicated 5 V plugged; if unit boots on plug, it should shut down after ~15 min once charge is detected.  
- **Abort:** unplug AC (if detection clears) or `sudo systemctl stop sls-charge-idle-poweroff` while working.  
- **Investigation session:** if you must run on AC with charge detected, stop the service or set `ENABLED=0` temporarily.  
- **TMAX OTG field power:** ship with `ENABLED=0` in image or post-install conf.

## Related

- [devices/rca-w101as23t2.md](devices/rca-w101as23t2.md) — wake on AC, dedicated charger  
- [devices/kinect-portable-power.md](devices/kinect-portable-power.md) — 12 V vs charge  
- [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md)  
