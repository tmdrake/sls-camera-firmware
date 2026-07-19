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
