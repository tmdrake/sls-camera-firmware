# Hardware assumptions

## Sensor

- **Xbox 360 Kinect** (NUI): motor `045e:02b0`, audio `045e:02ad`, camera `045e:02ae`  
- External **Kinect power brick** required  
- USB 2.0 host; avoid hubs when possible  

## Compute

- Phase 1–2 primary target: **x86_64** tablet or mini-PC (Intel/AMD)  
- ARM64 tablets: later (re-fetch wheels/debs for arch)  

## Display

- Touchscreen preferred; app supports large Qt buttons + keyboard  
- Brightness: **app Settings owns it** (sysfs / brightnessctl / xrandr)  
- **Disable auto-rotate** and desktop auto-brightness fighting the app — see [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md)  

## Power

- Prefer **external DC** for Kinect + tablet during investigations  
- App shows battery % when present  
- **Disable suspend / lid sleep / idle blank** on appliance images (`logind` drop-in + session `xset`) — [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md)  
- Full “inhibit while app running” remains Phase 3 product work  

## VM validation (optional)

Kinect can be **USB-passed** into the Phase 1 KVM guest for freenect smoke (all three IDs: `02b0` / `02ae` / `02bb`). Proven live depth in guest; not a substitute for tablet bring-up.

## Captures storage

- Writable **`/data`** partition or folder for snaps/AVI when root is locked  

See also `sls-camera` → `hardware/README.md`.
