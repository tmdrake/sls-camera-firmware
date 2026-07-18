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
- Brightness: app Settings uses sysfs / brightnessctl / xrandr  

## Power

- Prefer **external DC** for Kinect + tablet during investigations  
- App shows battery % when present; full no-suspend policy is Phase 3  

## Captures storage

- Writable **`/data`** partition or folder for snaps/AVI when root is locked  

See also `sls-camera` → `hardware/README.md`.
