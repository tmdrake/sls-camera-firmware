# Goodix touch (Cherry Trail tablets) — intermittent death

**Seen on:** tablet-01 RCA W101AS23T2 (`Goodix Capacitive TouchScreen` / ACPI `GDIX1002:00`).  
**Symptom:** Touch works after some boots, then **gone** — mouse/USB still work; `xinput` has **no** Goodix device.

## Diagnosis (lab 2026-07-21)

```text
Goodix-TS i2c-GDIX1002:00: supply AVDD28 not found, using dummy regulator
Goodix-TS i2c-GDIX1002:00: supply VDDIO not found, using dummy regulator
i2c_designware …: controller timed out
Goodix-TS …: Error reading 1 bytes from 0x8140: -110
Goodix-TS …: I2C communication failure: -110
probe with driver Goodix-TS failed with error -110
```

| Check | Dead touch | Healthy |
|-------|------------|---------|
| `xinput list` | No Goodix pointer | `Goodix Capacitive TouchScreen` |
| `dmesg \| grep -i goodix` | probe **-110** I2C timeout | successful probe, no timeouts |
| Sysfs | device may show `waiting_for_supplier` | bound to `Goodix-TS` driver |

Not caused by SLS app landscape lock (CTM only applies when the device already exists). Module `goodix_ts` can stay loaded while the **device never binds**.

## Likely class of bug

Cherry Trail + Goodix over **i2c_designware**:

- Touch controller power (AVDD/VDDIO) described poorly in ACPI → dummy regulators  
- I2C bus busy/timeout during early boot or after power-state churn  
- Intermittent: same image works, then next boot probe fails until **cold** power cycle  

## Recovery (try in order)

1. **Soft rebind** (sometimes works if chip woke later):

```bash
sudo bash -c '
  echo GDIX1002:00 > /sys/bus/i2c/drivers/Goodix-TS/unbind 2>/dev/null || true
  sleep 1
  modprobe -r goodix_ts 2>/dev/null || true
  sleep 1
  modprobe goodix_ts
  sleep 2
  dmesg | tail -20 | grep -i goodix
'
xinput list | grep -i goodix
```

2. **Warm reboot** — often **not** enough if regulators stay wrong.  

3. **Cold power cycle** (best recovery on this RCA):  
   - Full shutdown (app Quit → power off or `poweroff`)  
   - Remove power / hold power long enough for rails to drop  
   - Boot again  
   - Confirm `xinput` shows Goodix before relying on touch  

4. **Lab:** keep a USB mouse/keyboard (already used for setup).

## Firmware / field notes

- Document on device pages: **touch flaky — cold boot if dead**.  
- Optional later: delayed `systemd` oneshot that rebinds Goodix 10–15 s after graphical session (race mitigation), not a guaranteed fix.  
- Do **not** blame landscape rotate first when `xinput` has no touch device.  
- Phase 3 kiosk still needs keyboard/SSH fallback when touch is dead.

## Related

- [devices/rca-w101as23t2.md](devices/rca-w101as23t2.md)  
- [EFI-BOOT.md](EFI-BOOT.md) — separate GRUB 30s issue  
- [LIVE-SESSION.md](LIVE-SESSION.md) — landscape + touch CTM when device is present  
