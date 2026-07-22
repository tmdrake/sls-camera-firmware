# Device: RCA W101AS23T2

**Unit ID:** `tablet-01`  
**Inventory / hostname (Windows):** `SLS-CAMERA`  
**Source:** Windows 10 `msinfo32` export `tablet.txt` on USB “PEN DRIVE” (2026-07-18).  
**Tracking:** [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7) hardware tree · UI fit [#6](https://github.com/tmdrake/sls-camera/issues/6)  
**Field kit:** Kinect 360 + portable power — [kinect-portable-power.md](kinect-portable-power.md)

## Summary

| Field | Value | SLS notes |
|-------|--------|-----------|
| Manufacturer | **RCA** | Budget slate |
| Model | **W101AS23T2** | |
| Board | RCA **WT9S10WW05** | |
| CPU | **Intel Atom x5-Z8350** @ 1.44 GHz (4C/4T, Cherry Trail) | 64-bit capable; slow for MediaPipe — expect lower FPS |
| RAM | **2.00 GB** (~1.93 GB usable) | **Tight** for Qt + pose; swap/zram helpful; avoid heavy desktop chrome |
| System type (Windows) | **X86-based PC** | Almost certainly **32-bit Windows 10**; still install **amd64 Lubuntu** (CPU is x86_64) |
| Platform role | Slate (tablet) | |
| BIOS | BSR4WEUS-S10W05-RCA-V29 (2018-07-14) | |
| BIOS mode | **UEFI** (ia32 GRUB on this unit) | Match ISO boot mode; 30s delay = GRUB recordfail — [EFI-BOOT.md](../EFI-BOOT.md) |
| Secure Boot | **Off** | Good for Lubuntu |
| TPM / BitLocker auto | Not usable | Fine for field Linux |
| Display | **Intel HD Graphics** (Cherry Trail, DEV_22B0) | |
| Resolution (Windows) | **800 × 1280 @ 59 Hz** | Native **portrait**; appliance locks **1280×800** landscape |
| Storage | **Biwin ~28.8 GB** fixed disk | ~28 GB C: NTFS, ~16.6 GB free at capture time |
| Free for Linux | Tight if dual-boot; full wipe OK for appliance | Aim minimal install |
| Touch | **Goodix** (`GDIX1002:00`) | **Intermittent I2C death** on Linux (probe -110); **cold power-off** best fix; soft helper at boot — see [PMIC / warm reboot](#pmic--warm-reboot-vs-cold-start-rca-lab) · [TOUCH-GOODIX.md](../TOUCH-GOODIX.md) |
| USB | Intel USB 3.0 xHCI (22B5) | Prefer direct port for Kinect |
| Windows | 10 Home 19044 | Wipe candidate for Stage A field USB |

## Implications for blow-and-go

1. **Install Lubuntu 26.04 amd64** (UEFI). Do not use i386 ISO.  
2. **RAM 2 GB:** use lightweight session (already LXQt); consider `zram`; monitor OOM during pose — [PERFORMANCE.md](../PERFORMANCE.md).  
3. **Landscape lock:** native glass is **800×1280** portrait; firmware forces **1280×800** via `sls-lock-landscape` with **`SLS_LANDSCAPE_ROTATE=right`** + touch CTM/map-to-output (live-validated fleet policy).  
4. **~29 GB eMMC:** full-disk Lubuntu + `/opt/sls-camera` venv is OK; leave room for `/data/sls-captures`.  
5. **Kinect:** external brick + USB; after wipe, no VM passthrough script.  
6. **Goodix / PMIC:** first boot checklist — if no touch, keyboard/SSH fallback; prefer **cold power-off** over soft reboot when platform is weird; appliance enables soft stabilize — [PMIC section](#pmic--warm-reboot-vs-cold-start-rca-lab).  
7. **Speakers / DrakeVox:** full RCA audio setup (SST + Speaker path + **OUT volume**) — [below](#rca-speaker-fix-full-stack-lab-validated-2026-07). Lab: **unplug OTG** when debugging.  

## Linux driver reality (lab 2026-07)

This unit **can** run the SLS appliance (Lubuntu 26.04, autologin, app, quit→poweroff, landscape), but **Cherry Trail + vendor ACPI** makes it a rough Linux citizen. Expect more “platform” pain than app bugs.

| Area | Reality on this RCA |
|------|---------------------|
| **SLS app path** | Works once install + Kinect 12 V are right |
| **Goodix touch** | Usually OK in field (**OTG port not used** for normal SLS). Lab only: hub/NIC on **OTG** killed Goodix (I2C -110); unplug restored touch — [TOUCH-GOODIX.md](../TOUCH-GOODIX.md) |
| **PMIC / warm reboot** | Soft reboot often leaves **weird** touch/I2C/charge state; **cold start** fixes most. Software helper mitigates, does not replace cold off — [below](#pmic--warm-reboot-vs-cold-start-rca-lab) |
| **Brightness (Settings)** | App owns ±10%; often **broken** until video-group sysfs write + prefer `intel_backlight` — [below](#brightness-settings-rca) · [POWER-AND-DISPLAY.md](../POWER-AND-DISPLAY.md) |
| **Boot delay ~30 s** | GRUB **recordfail** after hard off — **setup must set** `GRUB_RECORDFAIL_TIMEOUT=0` (install + `grub.d/50-sls-recordfail.cfg`). Lab wipe still saw loader ~38 s when this was skipped. — [EFI-BOOT.md](../EFI-BOOT.md) · [FIRST-BOOT.md](../FIRST-BOOT.md) |
| **UEFI** | **ia32** GRUB on 32-bit firmware + amd64 OS — normal for this class, still fiddly |
| **Kinect** | Not a tablet driver issue if only `02b0`; **12 V / charger path** — [kinect-portable-power.md](kinect-portable-power.md) |
| **CPU / RAM** | Z8350 + **2 GB** — MediaPipe is CPU-bound; usable, not snappy — [PERFORMANCE.md](../PERFORMANCE.md) |
| **Audio / speakers** | RT5651 present. Needs **three-part fix**: (1) SST not SOF (2) force Speaker path (3) **OUT Playback Volume ≠ 0**. Recipe — [RCA speaker fix](#rca-speaker-fix-full-stack-lab-validated-2026-07) |
| **i2c / pinctrl** | Occasional designware timeouts, pinctrl probe errors — same generation as touch flakiness |

**Takeaway for BOM:** fine as a **lab / wipe-load proving** tablet; for **production fleet**, prefer a better-supported SoC (e.g. N100-class) if driver tax stays high. Do not over-invest in Goodix/ACPI heroics on this chassis unless volume forces it.

### PMIC / warm reboot vs cold start (RCA lab)

**Observed (tablet-01, 2026-07):** after a **soft reboot** (`reboot`, app restart path that does not drop rails), the unit can do “weird stuff” — Goodix missing or flaky (I2C **-110**), designware timeouts, AXP288 charge UI lies (`online=0` while LED charges). A **cold start** (full power-off, rails actually drop, then boot) reliably clears most of that.

| Kind of reset | What it does on this chassis | When to use |
|---------------|------------------------------|-------------|
| **Cold start** | Power **off** long enough for **AXP288 / EC / I2C rails** to drop, then power on | Gold standard when touch is dead, OTG role stuck, or “everything is weird” after soft reboot |
| **Warm / soft reboot** | Kernel restarts; **PMIC often stays live** | Everyday restart; may leave Goodix/I2C wedged |
| **Software stabilize** | Delayed oneshot after boot (below) | Best-effort recovery of **many** warm-boot Goodix failures — **not** a rail reset |

**Why cold works:** Cherry Trail + vendor ACPI + **AXP288** leave touch rails poorly described (dummy `AVDD28`/`VDDIO` in dmesg). Soft reboot does not re-sequence those paths the way a full power cut does. Software cannot fully fake a PMIC hard reset.

#### Software helper (enabled on appliance install)

Install enables **`sls-pmic-startup-stabilize.service`** → `/usr/local/bin/sls-pmic-startup-stabilize` (config `/etc/sls/pmic-startup.conf`).

After multi-user (~**12 s** delay, then up to **3** retries):

1. Force runtime PM **`on`** for designware I2C (`808622C1:*`) and Goodix sysfs paths  
2. If no Goodix input / unbound `GDIX1002:00` → unbind / `modprobe` / rebind **goodix_ts**  
3. Log: `/data/sls-captures/pmic-startup.log` (fallback `/var/log/sls-pmic-startup.log`)

```bash
systemctl status sls-pmic-startup-stabilize
tail /data/sls-captures/pmic-startup.log
# disable if needed: ENABLED=0 in /etc/sls/pmic-startup.conf
```

| Expect | Do not expect |
|--------|----------------|
| Warm reboot recovers Goodix more often without operator action | Fix when OTG still brownouts the bus (unplug / use powered hub first) |
| Log line `Goodix recovered` / `Goodix present` | Replace cold start for hard-wedged PMIC |
| Safe no-op when touch already healthy | Fix wake-on-AC (BIOS/EC — ignore for SW) |

Shared detail / manual rebind: [TOUCH-GOODIX.md](../TOUCH-GOODIX.md).

#### Operator recovery order (this RCA)

1. **Lab only:** if OTG has hub/NIC load and touch is dead → unplug OTG or use **self-powered** hub; re-check `xinput`.  
2. Soft rebind / wait for **`sls-pmic-startup-stabilize`** (or run the script once as root).  
3. **Cold power cycle:** app Quit → power off (or `poweroff`); wait until fully off; power on; confirm Goodix before relying on touch.  
4. Keep USB mouse/keyboard available for setup when touch is dead.

#### Field vs lab on this unit

| Context | Guidance |
|---------|----------|
| **Field investigations** | OTG **not** used for normal SLS; cold power-off if touch/platform is weird after a soft reboot |
| **Lab (SSH / stick on OTG)** | Prefer **powered hub**; expect more PMIC/I2C stress than field |
| **Preferred shutdown** | Full **poweroff** (app exit 10 / Quit) over casual soft reboot when closing a session |

**Deploy note:** helper is in firmware (`sls-pmic-startup-stabilize`); enable on unit if missing after older install. TMAX (tablet-02) is the HW/SW control — do not assume this RCA PMIC tax applies there until proven.

### Brightness (Settings) — RCA

**Symptom (lab):** SLS Settings → **Brightness − / +** does nothing, shows **n/a**, or shows a % with greyed buttons. Desktop brightness applet is not the field path (hidden LXQt power manager).

**How the app tries to control the panel** (`sls_viewer/backlight.py`):

1. **sysfs** `/sys/class/backlight/*/brightness` (real panel)  
2. **`brightnessctl`** (if installed)  
3. **`xrandr --brightness`** (software gamma — weak/no-op on some Cherry Trail modes)

| Failure mode | What you see | Fix |
|--------------|--------------|-----|
| sysfs exists, **root-only write** | % shown, **± disabled** (older app) or set fails | `sls` in **video**; udev `99-sls-backlight.rules`; install re-chmods nodes |
| Wrong node first (`acpi_video0` before `intel_backlight`) | Write “works”, panel unchanged | App prefers **intel_backlight** (and similar) over `acpi_video*` |
| No backlight class | **n/a** | Rare ACPI gap; try `brightnessctl` / xrandr; cold boot if PMIC wedged |
| Only xrandr soft dim | Slight gamma change, not LED backlight | Acceptable fallback; fix sysfs permissions for real backlight |

#### Appliance pieces (after reinstall / overlay update)

| Piece | Role |
|-------|------|
| `usermod -aG video sls` | Already in install-appliance |
| `/etc/udev/rules.d/99-sls-backlight.rules` | `chgrp video` + `g+w` on brightness |
| Package **`brightnessctl`** | Offline seed in `packages/apt-packages.txt` |
| App pin with fixed `backlight.py` | Prefer real panel; enable ± when set path exists |

#### Lab checklist (this unit)

```bash
# As sls on the tablet
ls -la /sys/class/backlight/
# expect e.g. intel_backlight (and maybe acpi_video0)
cat /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness
id | tr ',' '\n' | grep video

# One-shot fix without full reinstall (root):
for f in /sys/class/backlight/*/brightness; do
  chgrp video "$f"; chmod g+w "$f"
done
# then re-open Settings and use ±

# Confirm write as sls (use the real node name from ls above):
B=$(ls /sys/class/backlight | head -1)
echo 40 > /sys/class/backlight/$B/brightness   # should not say Permission denied
```

Tooltip on Settings brightness shows active **backend** (`sysfs:intel_backlight`, `brightnessctl`, `xrandr:…`). Prefer **sysfs** on this RCA.

**Related:** panel power / PMIC flakiness after warm reboot can make backlight control flaky even when permissions are right — cold start if the panel stays stuck; [PMIC section](#pmic--warm-reboot-vs-cold-start-rca-lab). General policy: [POWER-AND-DISPLAY.md](../POWER-AND-DISPLAY.md).

### RCA speaker fix (full stack) — lab validated 2026-07

**Goal:** DrakeVox (and any app audio) audible on the **panel speakers**.

**Hardware:** Yes — internal speakers + Realtek **RT5651** (`ACPI 10EC5651`). Newer lab unit than tablet-02 TMAX. Windows uses these speakers; Linux does **not** until the **full setup stack** below is applied (install-appliance does this when overlay is current).

#### Problem (three independent failures)

| # | Failure | Symptom | Without fix |
|---|---------|---------|-------------|
| **1** | Default **SOF** DSP path | `sof-audio-acpi-intel-byt: No matching ASoC machine driver` | Only HDMI LPE + PipeWire **Dummy Output** — volume at 100% still silent |
| **2** | False **Headphone Jack** sense | Jack read-only `values=on` even with nothing plugged | UCM enables **Headphones**, **mutes Speaker** — card exists but panel silent |
| **3** | **`OUT Playback Volume` = 0** | Card + Speaker on + PipeWire 100% | Still **silent** — codec analog OUT gain left at zero by UCM (lab wipe 2026-07) |

Parts stack: **1** creates the card → **2** routes to speakers → **3** unmutes the OUT gain. Skipping any step = no DrakeVox on the panel.

#### Fix part 1 — force Intel SST (not SOF)

| Piece | Path / value |
|-------|----------------|
| Conf | `/etc/modprobe.d/sls-audio-sst.conf` |
| Overlay | `overlay/etc/modprobe.d/sls-audio-sst.conf` |
| Option | `options snd-intel-dspcfg dsp_driver=2` |
| Kernel 7.0 meaning | `0=auto 1=legacy **2=SST** 3=SOF 4=AVS` — use **`2`**, not `1` |
| Blacklist | `blacklist snd_sof_acpi_intel_byt` |
| Install | `install-appliance` when `SLS_AUDIO_SST≠0` (default on); or `scripts/apply-audio-sst-on-target.sh` |
| After write | `update-initramfs -u` then **cold** power-off/on (see [reboot caution](#sst-force--reboot--bios-caution)) |

**Success (part 1):**

```text
aplay -l
  card 1: bytcrrt5651 — RCA-W101AS23T2-…-WT9S10WW05
lsmod | grep rt5651
  snd_soc_sst_bytcr_rt5651 …
  snd_soc_rt5651 …
```

#### Fix part 2 — force Speaker path (false HP jack)

UCM (`/usr/share/alsa/ucm2/codecs/rt5651/HeadPhones.conf`) turns **Speaker off** when it thinks a jack is present. On this RCA, jack sense is often stuck **on**.

| Piece | Role |
|-------|------|
| `/usr/local/bin/sls-audio-speakers` | Speaker **and** Headphone/HPO **on**, LOUT MIX DAC on, **OUT=39** |
| `sls-audio-speakers.service` | Boot oneshot + re-run after ~8 s (after UCM/WirePlumber settle) |
| App `sls_viewer/tts.py` | Same on **every** DrakeVox speak |

Why PipeWire says **Headphones**? That is the UCM default sink name. Streams (eSpeak, DrakeVox/`sounddevice`) play to it — so **do not mute HPO** or the panel can stay silent even with Speaker on. Keep both paths on + OUT volume.

#### Fix part 3 — `OUT Playback Volume` (setup critical)

**Lab validated (wipe 2026-07):** after parts 1–2, panel was **still silent**. Mixer showed:

```text
amixer -c1 cget name='OUT Playback Volume'
  : values=0,0          # silent (−46.5 dB floor)
# fixed:
  : values=39,39        # max
```

PipeWire / app “100%” does **not** move this ALSA control. It must be set explicitly.

| Piece | Action |
|-------|--------|
| `sls-audio-speakers` | `cset name='OUT Playback Volume' 39` every boot/run |
| `tts.py` / DrakeVox | same before each speak |
| Manual | `amixer -c1 cset name='OUT Playback Volume' 39` |

**Success (parts 2 + 3):**

```bash
amixer -c1 sget Speaker                      # Mono: Playback [on]
amixer -c1 cget name='OUT Playback Volume'   # values=39,39 — not 0,0
sudo /usr/local/bin/sls-audio-speakers       # one-shot if still quiet
espeak-ng -a 200 "test"                      # should hear panel
```

#### Full stack checklist (install / wipe setup)

Part of **normal appliance setup** on RCA (current SLS-MEDIA + `install-from-usb`):

1. Install applies overlay: SST conf, `sls-audio-speakers` + service, app with TTS OUT-volume force.  
2. `update-initramfs -u` when SST conf is new.  
3. **Cold power-off → power on** (I2C/codec often need it; avoid soft reboot).  
4. Lab: **unplug OTG** for soak if touch/audio flaky — [OTG notes](#otg-port-rca--lab-debug-notes).  
5. **Verify audio setup:**

```bash
# 1 — card
test -f /etc/modprobe.d/sls-audio-sst.conf
aplay -l | grep -i bytcr
# 2 — speaker path + OUT gain (both required)
systemctl is-enabled sls-audio-speakers
amixer -c1 sget Speaker
amixer -c1 cget name='OUT Playback Volume'    # must be 39,39
# 3 — hear it
export XDG_RUNTIME_DIR=/run/user/$(id -u)
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0
espeak-ng -a 200 "setup ok"
# or Settings → DrakeVox generate
```

| Healthy | Broken |
|---------|--------|
| `bytcrrt5651` in `aplay -l` | Only HDMI / Dummy Output → part 1 / cold boot |
| `Speaker` **[on]** | Speaker **[off]** → part 2 / `sls-audio-speakers` |
| `OUT Playback Volume` **39,39** | **0,0** → part 3 (silent despite “100%”) |
| DrakeVox / espeak audible | Word on screen only |

#### App behavior (all tablets; critical on RCA)

On each DrakeVox speak (`tts.py`):

1. Unmute + default sink / ALSA **100%** (`wpctl` / `pactl` / `amixer`)  
2. If a card has **Speaker**: Speaker/LOUT path + **`OUT Playback Volume` 39**  
3. Peak-normalize soft espeak PCM; CLI fallback **-a 200**
#### SST force — reboot / BIOS caution

**Lab (2026-07):** conf + `update-initramfs` + **remote soft reboot** once left the unit stuck — operator needed **manual reboot** and a **BIOS reset**. **Cold reboot** after that restored a good state.

| Do | Avoid |
|----|--------|
| **Cold power-off / on** after initramfs or platform weirdness | Unattended remote `reboot` with no hands on tablet |
| Stay at the unit for first boot after audio modprobe | Assuming BIOS reset is always required |
| After BIOS defaults: re-check boot order, Secure Boot **Off** | Expecting BIOS to store Linux audio settings |

BIOS reset does **not** remove eMMC files (`sls-audio-sst.conf` survived). Re-check `aplay -l` for `bytcrrt5651`.

**Fleet:** RCA / Cherry Trail RT5651 only until TMAX is tested. Skip SST: `SLS_AUDIO_SST=0` at install.

#### Manual apply (older image without reinstall)

```bash
# On tablet as root (or from firmware tree)
sudo cp overlay/etc/modprobe.d/sls-audio-sst.conf /etc/modprobe.d/
sudo install -m 755 overlay/usr/local/bin/sls-audio-speakers /usr/local/bin/
sudo install -m 644 overlay/etc/systemd/system/sls-audio-speakers.service \
  /etc/systemd/system/
sudo update-initramfs -u
sudo systemctl daemon-reload
sudo systemctl enable --now sls-audio-speakers.service
# Then COLD power cycle — not soft reboot
# Redeploy app pin with updated tts.py for speak-time speaker force
```

Helper: `scripts/apply-audio-sst-on-target.sh` (SST conf only; still need speakers oneshot + cold cycle).

### OTG port (RCA) — lab debug notes

**Field:** OTG is **not** part of normal SLS on this RCA (Kinect + charge use other paths).

**Lab (current practice, 2026-07):** after cold reboot / platform weirdness, **unplug OTG** (hub + NIC/stick) when chasing touch, PMIC, or random flakiness. OTG load has killed Goodix and stressed power/role switching. Prefer **SSH over a short session with OTG**, then **unplug OTG for soak/audio/touch tests**.

| Use | Guidance |
|-----|----------|
| **Field investigations** | OTG **not** required; leave empty |
| **Lab bring-up** | OTG OK for **USB stick + external NIC**, prefer **self-powered hub** |
| **After cold reboot / audio/touch debug** | **Unplug OTG** for now until platform is stable — see lab note above |
| **Hub** | Self-powered; hub power on before tablet |
| **Touch risk** | Unpowered OTG load → Goodix I2C -110; unplug often restores touch |
| **OTG “died”** | role=`host`, `lsusb`, dmesg; not SLS harden |

### OTG USB death — debug checklist (lab)

When OTG seems dead but “SLS USB” / other paths work:

1. **Role:** `cat /sys/devices/pci0000:00/*/intel_xhci_usb_sw/usb_role/*/role` → expect **`host`** (not `device`/`none`).  
2. **Enumerate:** plug stick directly into OTG (no hub) → `lsusb` / dmesg `new high-speed USB device`.  
3. **Self-powered hub:** hub power **on** before tablet; then stick + NIC.  
4. **Not our software:** harden does **not** mask `udisks2`/xhci; AutoRun only kills the **popup**.  
5. **Cable / port:** OTG-capable cable if the jack needs ID pin; try another cable.  
6. **Charge jack vs OTG:** dedicated 5 V charge path is separate; don’t confuse “not charging in UI” with OTG host death.  

Lab snapshot (2026-07-21 ~16:39): role **host**, hub + Cruzer + RTL8153 + mouse **did** enumerate on `xhci` — OTG path was alive in that session.

### Charger plugs in → tablet powers on

**Resolved as BIOS/EC behavior** — unit powers on when dedicated 5 V AC is attached. **Ignore for software/firmware work** (not a Lubuntu/SLS bug). Optional BIOS toggle only if the vendor menu exposes “Power on AC / Wake on AC.”

| Approach | Note |
|----------|------|
| **BIOS/EC** | Root cause; leave alone unless a setup option exists |
| **Linux charge-idle** | Still useful: if charge is detected for **15 min**, power off for unattended charge — [CHARGE-IDLE-POWEROFF.md](../CHARGE-IDLE-POWEROFF.md) (**lab OK**) |
| **AXP288 UI** | May still show `online=0` while LED charges — reporting quirk only |

**Fleet contrast:** tablet-02 charges via **OTG control circuit** and may run while powered — set `ENABLED=0` in `/etc/sls/charge-idle.conf` on that class so it does not auto-shutdown.

**HW vs SW (touch / OTG flakiness):** RCA lab showed intermittent Goodix/OTG stress. **tablet-02** is the control: same appliance image — if TMAX is clean, RCA issues lean **hardware**; if both fail the same way, lean **software/image**.

## Phase 1 / wipe status

- **Wiped** Lubuntu 26.04 appliance (lab): boot → app → shutdown OK; touch/Kinect power are the main field risks.  
- Fill pass/fail on [HARDWARE-MATRIX](https://github.com/tmdrake/sls-camera/blob/main/software/linux/docs/HARDWARE-MATRIX.md) / #7 as QA continues.

## Files

- Raw export (operator USB): `tablet.txt` (UTF-16 msinfo)  
- This summary: `docs/devices/rca-w101as23t2.md`  
- Speaker fix overlay: `overlay/etc/modprobe.d/sls-audio-sst.conf`, `overlay/usr/local/bin/sls-audio-speakers`, `overlay/etc/systemd/system/sls-audio-speakers.service`  
- App: `sls-camera` `software/linux/viewer/sls_viewer/tts.py` (max volume + Speaker path on speak)  

