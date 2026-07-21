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

## Fix (appliance — applied by `install-appliance.sh`)

```bash
# /etc/default/grub
GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0

sudo grub-editenv /boot/grub/grubenv unset recordfail   # clear sticky flag
sudo update-grub
```

After that, hard power-off should **not** cost an extra half minute at GRUB.

## Manual check

```bash
systemd-analyze                    # look at "loader" time
sudo cat /boot/grub/grubenv        # recordfail=1?
grep TIMEOUT /etc/default/grub
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
