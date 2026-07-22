# First boot (appliance)

## Lab VM credentials (rebuild standard)

| User | Password | Purpose |
|------|----------|---------|
| **`sls`** | **`20260717`** | Appliance autologin, SSH, field app session (**use this**) |

Lab-only — change on real tablets. Full rebuild procedure: **[VM-REBUILD.md](VM-REBUILD.md)**.

## Phase 1 (install-appliance.sh)

After install on a blank Ubuntu/Lubuntu system:

1. Run **`install-appliance.sh`** / **`install-from-usb.sh`** (includes freenect + Kinect audio **when** debs/UAC are on the pack or network works).  
2. **Confirm Kinect audio** (required for spectrum / Record mic — see [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md) § Kinect audio):

   ```bash
   # If spectrum still says "default" or package missing:
   sudo /path/to/firmware/scripts/install-kinect-audio-on-target.sh
   # unplug/replug Kinect, then:
   arecord -l
   ```

3. **Reboot** — on **RCA tablet-01**, prefer **cold power-off → power on** (not soft reboot) so SST speakers + PMIC settle — [rca-w101as23t2.md](devices/rca-w101as23t2.md#rca-speaker-fix-full-stack-lab-validated-2026-07).  
4. Auto-login as user **`sls`** (SDDM on Lubuntu 26.04; also LightDM/GDM when present)  
5. Session autostart: **landscape lock** + DPMS off, then **`/usr/local/bin/sls-camera`** as `sls`  
6. SLS app opens fullscreen (expect width ≥ height; native portrait panels are rotated)  

**Where is the app if you don’t see it?**

| Path | Role |
|------|------|
| `/usr/local/bin/sls-camera` | Launcher (in `$PATH`) |
| `/opt/sls-camera/` | App tree + `software/linux/viewer/` venv |
| **Applications menu → SLS Camera** | Desktop entry from install |
| `~/Desktop/sls-camera.desktop` | Shortcut on Lubuntu desktop |
| `~/.config/autostart/sls-camera.desktop` | Auto-start on login |

Manual smoke (no Kinect): `sls-camera --demo` or `DISPLAY=:0 sls-camera --demo`.

**Desktop still present:** install does **not** remove Lubuntu/LXQt. The app covers it; if the app exits, you get the normal desktop. Full chrome strip is **Phase 3** — [KIOSK-DESKTOP.md](KIOSK-DESKTOP.md). “Harden” today mainly means unused **services** ([HARDEN-HARDWARE.md](HARDEN-HARDWARE.md)), not deleting the DE.

If a temporary ISO install user still exists (e.g. leftover desktop scrap), remove it and keep only **`sls`** — see [VM-REBUILD.md](VM-REBUILD.md).

## Wipe + reload (field tablet checklist)

**Ship bar for the installer USB is this hardware checklist** — not “VM can run `--demo`.” Phase 1 VM is optional for app UI/TTS latency only ([ARCHITECTURE.md](ARCHITECTURE.md)).

Use a **current SLS-MEDIA** stick (`scripts/50-build-field-usb.sh`; host: `APP_SRC=~/sls-camera` if app fixes are not yet on the remote pin).

1. **Wipe** — Lubuntu 26.04 amd64 UEFI, full disk; Secure Boot Off.  
2. Boot to eMMC → plug **SLS-MEDIA** → `bash install-from-usb.sh`.  
3. Expect install to apply: freenect/Kinect audio seeds, landscape, quiet session, **SDDM autologin + Relogin**, **`/etc/sudoers.d/sls-poweroff`** (Quit → power off), HW harden, **GRUB recordfail=0**, **RCA speakers** (SST + OUT volume), backlight udev, PMIC stabilize, **menu + Desktop launcher**, **`--no-auto-level`** (no motor).  
4. **Cold power cycle** (especially RCA).  
5. Lab: **unplug OTG** for touch/audio soak after bring-up.  
6. Verify: **fast GRUB** (below), app autostart (or menu **SLS Camera**), brightness ±, DrakeVox audible on RCA, Kinect depth when 12 V OK, **tilt motor does not move** on open.

### Kinect tilt / “no motor” (field default)

Fixed field mounts must not command the tilt motor. The appliance launcher injects **`--no-auto-level`** unless already present:

| Setting | Behavior |
|---------|----------|
| Default | No `freenect_set_tilt_degs` on open (LED still green) |
| Lab auto-level | `SLS_KINECT_AUTO_LEVEL=1 sls-camera` (or pass without `--no-auto-level` after unsetting) |
| App flag | `./run.sh --no-auto-level` (same contract as [sls-camera#10](https://github.com/tmdrake/sls-camera/issues/10)) |

`freenect` packages remain installed — depth/IR need them; only **motor move on open** is disabled.

### GRUB / “EFI” long boot delay (part of setup — all tablets)

Unclean power-off sets GRUB **`recordfail`** → default **~30 s** menu. Looks like an EFI hang; `systemd-analyze` shows it as **loader ~30–38 s**.

**Install must set** (via `install-appliance` / SLS-MEDIA):

| File | Setting |
|------|---------|
| `/etc/default/grub.d/50-sls-recordfail.cfg` | `GRUB_TIMEOUT=0` + `GRUB_RECORDFAIL_TIMEOUT=0` |
| `/etc/default/grub` | same `RECORDFAIL` pin + `update-grub` |
| `/boot/grub/grubenv` | `recordfail` cleared |

```bash
# Verify after install
grep -r RECORDFAIL /etc/default/grub /etc/default/grub.d/ 2>/dev/null
# expect GRUB_RECORDFAIL_TIMEOUT=0
sudo cat /boot/grub/grubenv          # should not stick recordfail=1 after clean boot
systemd-analyze                      # loader should not be ~30–38s
```

**Manual if missing (partial install / old stick):**

```bash
echo 'GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0' | sudo tee /etc/default/grub.d/50-sls-recordfail.cfg
sudo grub-editenv /boot/grub/grubenv unset recordfail
sudo update-grub
```

Detail: [EFI-BOOT.md](EFI-BOOT.md).

### RCA speaker setup (part of install — tablet-01)

Install must leave all three layers healthy (detail: [rca-w101as23t2.md](devices/rca-w101as23t2.md#rca-speaker-fix-full-stack-lab-validated-2026-07)):

| Step | What | Check |
|------|------|--------|
| 1 | SST not SOF | `aplay -l` → `bytcrrt5651` |
| 2 | Speaker path (not false HP-only) | `amixer -c1 sget Speaker` → **[on]** |
| 3 | **OUT Playback Volume** | `amixer -c1 cget name='OUT Playback Volume'` → **39,39** (not **0,0**) |

`sls-audio-speakers.service` + app DrakeVox speak run steps 2–3. If DrakeVox is silent but steps 1–2 look OK, step 3 was the wipe-lab failure mode.

```bash
systemctl is-enabled sls-audio-speakers
sudo /usr/local/bin/sls-audio-speakers   # re-apply if quiet
espeak-ng -a 200 "test"
```

Stick rebuild + Stage A layout: [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md).

Without a Kinect (VM smoke test), run:

```bash
/usr/local/bin/sls-camera --demo
```

### Quit → power off (required setup)

App confirms “Power off?” and exits **10**. Launcher runs passwordless:

```text
sudo -n /usr/sbin/poweroff   # needs /etc/sudoers.d/sls-poweroff
```

**Lab wipe (2026-07):** partial install left **sudoers missing** → log:

```text
exit 10: app requested power-off
sudo: interactive authentication is required
ERROR: all poweroff methods failed — see log and sudoers.d/sls-poweroff
```

Bare `systemctl poweroff` as user also fails (polkit / inhibitors). **Install must** drop:

| File | Mode | Content |
|------|------|---------|
| `/etc/sudoers.d/sls-poweroff` | `0440` | `sls ALL=(root) NOPASSWD: … poweroff, shutdown, systemctl poweroff` |

```bash
# Verify
sudo -n /usr/sbin/poweroff --help >/dev/null && echo poweroff_nopasswd_ok
test -f /etc/sudoers.d/sls-poweroff && sudo visudo -cf /etc/sudoers.d/sls-poweroff
# Fix
sudo install -m 440 /path/to/overlay/etc/sudoers.d/sls-poweroff /etc/sudoers.d/sls-poweroff
# then Quit from app again
```

See [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md). Overlay: `overlay/etc/sudoers.d/sls-poweroff`.

### Quit / power off (respects app request)

The launcher **`/usr/local/bin/sls-camera`** prefers the **app’s exit code** (product contract for [sls-camera#4](https://github.com/tmdrake/sls-camera/issues/4)):

| Exit code | Meaning | Launcher action |
|-----------|---------|-----------------|
| **0** | Clean quit | `SLS_QUIT_FALLBACK` (appliance default **`none`** — stay up) |
| **10** | Operator requested **host power-off** | Power off |
| **11** | Relaunch app | Restart launcher |
| other | Error / crash | Exit (no power off); optional `SLS_QUIT_ON_ERROR=restart` |

| Env | Values | Role |
|-----|--------|------|
| `SLS_QUIT_ACTION` | `shutdown` (appliance default), `exit` | Forces app Power-off-on-Quit mode (sls-camera#4) |
| `SLS_ON_QUIT` | `app` (default), `shutdown`, `restart`, `none` | How launcher reacts to exit codes |
| `SLS_QUIT_FALLBACK` | `none` (default), `shutdown`, `restart` | Only if app still exits **0** on Quit |

App pin: see `packages/app-ref.txt` (includes exit 10 + `SLS_CAPTURES_DIR`).  
Firmware handoff: app repo `software/linux/docs/FOR-FIRMWARE-TEAM.md`.

Lab VM credentials: **`sls` / `20260717`** — see [VM-REBUILD.md](VM-REBUILD.md).

Launcher debug log (guest): `/data/sls-captures/launcher.log` (or `/tmp/sls-camera-launcher.log`).

### SDDM autologin (required setup)

Install must leave:

| File | Content |
|------|---------|
| `/etc/sddm.conf.d/50-sls-autologin.conf` | `User=sls`, `Session=Lubuntu`, **`Relogin=true`** |
| `/etc/sddm.conf` `[Autologin]` | same (Lubuntu sometimes only had User/Session without Relogin) |

**Lab wipe (2026-07):** after partial install, greeter stuck — `50-sls-autologin.conf` **missing**, and journal:

```text
sddm-helper (... --user sls --autologin) crashed (exit code 1)
Auth: sddm-helper exited with 9
Greeter session started successfully
```

Without **`Relogin=true`**, a failed first autologin leaves the password greeter. Also ensure `~/.config` is owned by **`sls`** (not root) after install.

```bash
# Verify
cat /etc/sddm.conf.d/50-sls-autologin.conf
grep -A5 '\[Autologin\]' /etc/sddm.conf
# Fix
sudo tee /etc/sddm.conf.d/50-sls-autologin.conf <<'EOF'
[Autologin]
User=sls
Session=Lubuntu
Relogin=true
EOF
sudo chown -R sls:sls /home/sls/.config
sudo systemctl restart sddm
# or reboot — expect no greeter; app autostart
journalctl -u sddm -b --no-pager | tail -30
# look for: Authentication for user "sls" successful / Session started
```

### Login screen once instead of autologin

SDDM can drop to the greeter if the session **crashes** or is torn down mid-boot. With **`Relogin=true`**, the next attempt should autologin again as `sls`. Check:

```bash
journalctl -u sddm -b
# look for: sddm-helper crashed / Authentication error
```
### Screenshots (Phase 1 VM — Lubuntu 26.04)

Full-size images live in [`docs/images/`](images/README.md) (repo shortcut: `screenshots` → `docs/images`).

| | |
|--|--|
| Desktop after install | ![Lubuntu desktop](images/01-guest-desktop.png) |
| SLS Camera `--demo` | ![SLS demo UI](images/02-sls-demo-app.png) |

Operator should only need:

- Kinect **power brick** (operate 12 V) + USB  
- **Kinect audio** completed at install (or `install-kinect-audio-on-target.sh`) for spectrum / Record — not optional if field audio is required  


## Captures

- Preferred: `/data/sls-captures`  
- Launcher exports `SLS_CAPTURES_DIR` when that directory exists  

## Failure modes

| Symptom | Check |
|---------|--------|
| Black screen / no app | `journalctl -b`, autostart desktop file, `DISPLAY` |
| freenect BUSY | `lsmod \| grep gspca`; blacklist applied? |
| Spectrum says **default** / not Kinect mic | Offline pack should include `kinect-audio-setup` deb + `vendor/kinect/UACFirmware` from fetch; unplug/replug Kinect. Rebuild stick if missing. |
| **`install-from-usb` hangs** (ncurses EULA) | `kinect-audio-setup` asks Microsoft EULA; without debconf preseed, SSH/noninteractive install waits forever. Fixed in install-appliance (preseed before seed apt). Manual: accept **Yes** on tablet, or preseed — [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md) § Kinect EULA |
| **Blank screen** on some boots | Launcher waits for X + re-applies landscape; autostart delays 3s. If still blank: SSH, check `launcher.log`, restart `/usr/local/bin/sls-camera`. See [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md). |
| Spectrum silent | `libportaudio2`, Kinect USB Audio after firmware |
| DrakeVox silent on **RCA** speakers | Check all 3: `bytcrrt5651`, Speaker **on**, **`OUT Playback Volume` 39,39** (0,0 = silent). `sudo sls-audio-speakers`; cold cycle if no card; unplug OTG — [rca speaker setup](devices/rca-w101as23t2.md#rca-speaker-fix-full-stack-lab-validated-2026-07) |
| **Quit does not power off** | App exit **10** but host stays up: missing **`/etc/sudoers.d/sls-poweroff`** — see [Quit → power off](#quit--power-off-required-setup) |


## Factory reset (Phase 3)

Re-run `install-appliance.sh` or reflash ISO; wipe `/data` only if operator confirms investigation media can be discarded.
