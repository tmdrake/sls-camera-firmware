# Branding, splash, and bootscreens (production)

**Status:** planned — not implemented yet. Tracked on the firmware roadmap ([TODO.md](TODO.md) Phase 3 / backlog) and app [TODO branding](https://github.com/tmdrake/sls-camera/blob/main/docs/TODO.md).

Field product can ship a **quiet, branded boot → app** experience. Lab builds stay generic “SLS” until a production brand pack is frozen.

## Layers

| Layer | Operator sees | Owner | Priority |
|-------|----------------|-------|----------|
| **UEFI / OEM logo** | Power-on | Tablet vendor | Usually not customizable on fleet Cherry Trail units |
| **Plymouth bootsplash** | Kernel boot logo / spinner | **Firmware** | **High** for production feel |
| **GRUB** | Rare (hold Shift) | Firmware | Low — keep `quiet splash` |
| **SDDM greeter** | Login (normally **skipped** via autologin) | Firmware | Low unless session crashes to greeter |
| **Desktop wallpaper / LXQt** | Flash before app | Firmware | Medium — dark/minimal; **strip chrome** → [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md) |
| **App splash** | “Starting / Reconnecting …” | **App** (+ assets from firmware) | **Highest** day-to-day visibility |
| **In-app chrome** | Title, DrakeVox, dialogs, colors | **App** | High — config/env driven |

With SDDM autologin, invest first in **app splash + product name**, then **Plymouth**.

## Proposed layout (when implemented)

```text
sls-camera-firmware/
  branding/                         # or overlay/usr/share/sls-branding/
    README.md                       # how to swap a brand pack
    product.env                     # SLS_PRODUCT_NAME=… SLS_SPLASH_TITLE=…
    plymouth/                       # theme name, logo.png, script
    wallpaper.png                   # LXQt / desktop background
    sddm/                           # optional greeter theme
    app/
      splash.png                    # optional full-bleed splash art
      logo.png
```

`install-appliance.sh` would:

1. Install Plymouth theme (seed `plymouth` + theme files offline if needed).  
2. Set default theme + ensure boot cmdline includes `quiet splash` when safe.  
3. Install wallpaper; keep power/update popups hidden (already partial).  
4. Export branding via launcher env or `/etc/sls/branding.env` sourced by `/usr/local/bin/sls-camera`.  
5. Copy app assets under `/opt/sls-camera/...` or `/usr/share/sls-branding/app/`.

## App contracts (to implement in `sls-camera`)

| Knob | Purpose |
|------|---------|
| `SLS_PRODUCT_NAME` | Window title, HUD “SLS CAMERA”, quit dialogs |
| `SLS_SPLASH_TITLE` / `SLS_SPLASH_SUBTITLE` | Startup / reconnect splash text |
| `SLS_SPLASH_IMAGE` | Optional PNG path for splash |
| Overlay names | DrakeVox / product overlays without hardcoding (app TODO) |

Defaults remain current SLS strings when unset (dev desktops unchanged).

## Suggested build order

1. **App:** env/config for product name + splash strings/image.  
2. **Firmware:** `branding/product.env` + launcher source; ship assets on field USB.  
3. **Plymouth** theme + offline package seeds.  
4. Optional multi-customer **brand packs** (directory swap on the stick).

## What not to do yet

- Block wipe-load / RCA lab on branding.  
- Custom BIOS on these tablets (usually impossible).  
- Heavy greeter themes while autologin is the path.

## Related

- [TODO.md](TODO.md) — roadmap checkbox  
- [FIRST-BOOT.md](FIRST-BOOT.md) — operator first boot  
- [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md) — session policy  
- App: viewer splash in `pipeline.py`; chrome in `qt_app.py`  
