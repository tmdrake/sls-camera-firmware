# Kiosk desktop cleanup (hardening)

**Status:** partial today — full strip is **Phase 3 harden**.  
Track: [TODO.md](TODO.md) · related [BRANDING.md](BRANDING.md) · [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md) · [HARDEN-HARDWARE.md](HARDEN-HARDWARE.md).

Production appliances should boot to **SLS only**, not a full Lubuntu playground. Operators should not see file managers, update nags, taskbars under the app, or extra session users.

## Does the Lubuntu desktop “go away” when we harden?

**No — not today.** Two different “harden” concepts:

| What people mean | What install does now | Removes full desktop? |
|------------------|----------------------|------------------------|
| **`sls-disable-unused-hw`** ([HARDEN-HARDWARE.md](HARDEN-HARDWARE.md)) | Masks BT, ModemManager, CUPS, apport, fwupd, … | **No** — OS services only |
| **Quiet session** (this doc + install-appliance) | Hides update/power/screensaver autostart; no suspend; app autostart fullscreen | **No** — **LXQt/Lubuntu session still runs** under the app |
| **Phase 3 kiosk strip** (not implemented) | Empty panel, no desktop icons, optional single-app session | **Yes (goal)** — no stock playground |

**What you see after Phase 1 wipe + `install-from-usb`:**

```text
Power on → SDDM autologin sls → full Lubuntu/LXQt session starts
  → landscape lock + DPMS off
  → SLS Camera autostarts fullscreen (covers most of the desktop)
  → Quit → power off (exit 10)
```

If the app is not running (crash, Quit with fallback none, kill process), the **normal Lubuntu desktop is still there** — panel, wallpaper, pcmanfm, terminal, etc. That is intentional for lab debug until Phase 3.

**Field operators** mostly only ever see SLS fullscreen; **do not** assume the desktop OS was uninstalled.

## Goal (Phase 3)

```text
Power on → (optional branded bootsplash) → autologin sls → landscape
  → SLS Camera fullscreen → Quit → power off
```

No stock desktop chrome, no second admin user, no “explore the OS” surface.

## Already done (appliance install)

| Item | Mechanism |
|------|-----------|
| Autologin `sls` | SDDM + Relogin |
| Hide update notifier | `xdg/autostart` Hidden |
| Hide LXQt power manager | Hidden + conf |
| Hide xscreensaver autostart | Hidden |
| No suspend / DPMS | logind + `sls-disable-dpms` |
| App autostart | `~/.config/autostart/sls-camera.desktop` |
| Landscape lock | `sls-lock-landscape` |
| **No USB AutoRun popup** | pcmanfm-qt `[Volume] AutoRun=false` (still **MountRemovable=true** for Captures) |

## Still to do (Phase 3 harden)

- [ ] **Strip LXQt chrome** — panel, desktop icons, pcmanfm-qt desktop, runner, notifications as needed  
- [ ] **Minimal session** — dedicated Openbox/LXQt profile or single-app session (no Start menu flash)  
- [ ] **Wallpaper / empty desktop** — dark or branded; no default Lubuntu art ([BRANDING.md](BRANDING.md))  
- [ ] **Remove install-time users** — only `sls` (see [VM-REBUILD.md](VM-REBUILD.md))  
- [ ] **Disable leftover applets** — network tray optional for lab only; Bluetooth/print/update off for field  
- [x] **Disable unused system services/HW** — [HARDEN-HARDWARE.md](HARDEN-HARDWARE.md) (`sls-disable-unused-hw`)
- [ ] **Lock down escape hatches** — Ctrl+Alt+T / virtual terminals policy for production (lab keeps SSH)  
- [ ] **Boot → app latency** — reduce session startup so desktop never “settles” before SLS  
- [ ] **Document lab vs field** — lab may keep a thin panel for debug; field image does not  

## Suggested implementation (later)

1. Overlay LXQt/Openbox configs under `overlay/home/sls/.config/` (panel empty or absent).  
2. Optional `sls-session` desktop entry: start X → landscape → `sls-camera` only (no full LXQt).  
3. `install-appliance.sh` purges or masks noisy packages (safe list only).  
4. Verify on RCA (2 GB): less chrome = less RAM fight with MediaPipe.

## Not in scope here

- App UI layout (that is `sls-camera` #6/#7).  
- Plymouth bootsplash art (BRANDING).  
- Kinect power hardware (kinect-portable-power).

## Related product note

App repo TODO: *“Clean the desktop before a firmware package install”* — product intent; **implementation lives in this firmware repo** as Phase 3.
