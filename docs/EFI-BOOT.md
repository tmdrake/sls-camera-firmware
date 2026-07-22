# EFI / boot delays (fleet tablets)

Lab observation (RCA W101AS23T2 / tablet-01): boot “pops up” something and **waits ~30 s** before Linux continues. That is usually **not** a broken EFI firmware loop.

## Measured (tablet-01)

Example `systemd-analyze` after a recent reboot:

```text
firmware ~9.5s + loader ~37.6s + kernel ~2s + initrd ~10s + userspace ~13s
```

The **~30–38 s “loader”** slice is GRUB, not the kernel.

## Cause: GRUB `recordfail` (often after hard power-off)

| Setting | Default Ubuntu | Effect |
|---------|----------------|--------|
| `GRUB_TIMEOUT` | `0` + hidden | Normal boot: no menu |
| `GRUB_RECORDFAIL_TIMEOUT` | **30** if unset | After GRUB thinks last boot **failed**, show menu **30 s** |

Unclean shutdown (hold power button, battery pull, kernel panic, forced reboot) sets **`recordfail`** in `/boot/grub/grubenv`. Next boot: menu / delay even though “EFI Timeout: 0”.

Also common on these units:

- **32-bit UEFI** bootloaders: `\EFI\UBUNTU\GRUBIA32.EFI`, `\EFI\BOOT\BOOTIA32.EFI` (Cherry Trail) with **amd64** Linux — normal for this class; keep boot order **Ubuntu** first on internal eMMC.
- Extra USB sticks (SLS-MEDIA, installer) can add **firmware** time probing devices (~few seconds), separate from the 30 s GRUB menu.

## Fix (required **setup** — applied by `install-appliance.sh`)

**Part of every wipe/reload**, not optional polish. Lab RCA after incomplete install still measured **loader ~38 s** until this was applied.

| Deliverable | Path / action |
|-------------|----------------|
| Drop-in | `/etc/default/grub.d/50-sls-recordfail.cfg` (overlay + install) |
| Main file | `GRUB_RECORDFAIL_TIMEOUT=0` + `GRUB_TIMEOUT=0` in `/etc/default/grub` |
| Clear sticky | `grub-editenv … unset recordfail` |
| Rebuild menu | `update-grub` |

```bash
# What install writes (also in overlay/etc/default/grub.d/50-sls-recordfail.cfg)
GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0

sudo grub-editenv /boot/grub/grubenv unset recordfail
sudo update-grub
```

After that, hard power-off should **not** cost an extra half minute at GRUB. Listed on [FIRST-BOOT.md](FIRST-BOOT.md) wipe checklist.

## Manual check

```bash
systemd-analyze                    # "loader" should not be ~30–38s
sudo cat /boot/grub/grubenv        # recordfail=1?
grep -r RECORDFAIL /etc/default/grub /etc/default/grub.d/
sudo efibootmgr -v                 # BootOrder: Ubuntu on eMMC first
```
## Shutdown / reboot hygiene

| Prefer | Avoid |
|--------|--------|
| App **Quit → power off** (exit 10) | Holding power button every time |
| `sudo reboot` / clean shutdown | Pulling battery mid-write |

Clean power-off keeps `recordfail` clear even without `RECORDFAIL_TIMEOUT=0` (still set it for field abuse).

## Still investigate if

- Delay is **before** any GRUB/Linux splash (pure OEM logo 30 s) — firmware USB/boot order.  
- Boots USB instead of eMMC intermittently — unplug field sticks; fix `efibootmgr` order.  
- Black screen forever — different issue (display, kernel, SDDM).

## Related

- [PERFORMANCE.md](PERFORMANCE.md) — boot vs runtime cost  
- [FIRST-BOOT.md](FIRST-BOOT.md)  
- [TODO.md](TODO.md) Phase 3 EFI reliability  
