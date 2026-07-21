# Field kit: Kinect + portable power

Shared sensor kit for **tablet-01**, **tablet-02**, and future units.

## Kinect 360 (NUI)

| Interface | USB ID | Role |
|-----------|--------|------|
| Motor | `045e:02b0` | Tilt / LED |
| Camera | `045e:02ae` | Depth + IR (freenect) |
| Audio | `045e:02bb` (or `02ad` on some cables) | USB mic / spectrum |

- **Must** use external **Kinect power brick** (or equivalent portable DC supply that meets Kinect power).  
- USB data alone is not enough for the camera stack.  
- Prefer **direct tablet USB** (or short quality cable); avoid unpowered hubs.

### Symptom when 12 V is off

| `lsusb` sees | Meaning |
|--------------|---------|
| Only **`045e:02b0`** (motor) | Power path incomplete — depth/audio not up |
| **`02b0` + `02ae`** (+ often `02bb`) | Camera stack ready for freenect |

App UI can be fullscreen while freenect reports **No device found** if only the motor is present.

## Portable power supply

Both field tablets are run with a **portable power supply** feeding the Kinect (and optionally the tablet).

| Item | Record per kit |
|------|----------------|
| PSU type | brand/model, battery vs wall brick with extension |
| Output | voltage/current rating (must satisfy Kinect brick input or official brick) |
| Runtime | approx hours with tablet + Kinect |
| Cabling | Kinect proprietary power plug + USB to tablet |
| Safety | strain relief, no daisy-chain cheap hubs |

**Lab note:** On the Optiplex/VM, Kinect may use a wall brick; portable PSU is the **field** configuration.

### Legacy field charger variant (this lab kit)

Some **original / years-old** hardware used with the fleet has an **external charger** that **disables the Kinect 12 V line** while charging (by design of that pack, not a Linux bug).

| Mode | 12 V to Kinect | Expected USB | App depth |
|------|----------------|--------------|-----------|
| **Operate / field** (charger not cutting 12 V) | On | Motor + camera (+ audio) | Live |
| **Charge / charger active (this variant)** | **Off / inhibited** | Often **motor only** (`02b0`) | Splash / no depth |

**Operator rule:** do not expect depth while that charger path is disabling 12 V. Switch to the operate power path (battery or supply that feeds Kinect 12 V), wait a few seconds, unplug/replug **data USB** if needed, confirm `lsusb` shows **`02ae`**, then restart the app if it was already open.

Document which physical cable/PSU mode is “charge” vs “run” on the kit label so techs do not chase software.

## Linux checklist (after wipe-load)

```bash
lsusb | grep 045e
# expect motor + camera (+ audio)
# gspca should stay blacklisted (appliance install)
```

Optional audio firmware (not on public field USB):

```bash
sudo apt install kinect-audio-setup   # MS UAC blob — operator network or private drop
```

## VM lab vs field

| | VM (Phase 1) | Tablet field |
|--|--------------|--------------|
| Kinect USB | Host `vm-kinect-usb.sh reattach` | Native USB |
| Power | Host wall brick | **Portable supply** |
| App reconnect | Works if device on guest bus | Works on real unplug/replug |

## Related

- [HARDWARE.md](../HARDWARE.md)  
- App audio bring-up: `sls-camera` UBUNTU-SETUP / FIELD-INSTALL  
