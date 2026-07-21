SLS Camera — Lubuntu installer USB (OS only)
============================================

You are holding the **Lubuntu 26.04 installer** stick (not the full SLS offline pack).

LIVE BOOT (try before install)
  - Explore hardware, Wi‑Fi, touch, display. Changes vanish on reboot.
  - Do NOT run install-appliance.sh from live expecting it to stick on eMMC.

INSTALL OS TO THE TABLET
  1. Start the Lubuntu installer (desktop icon or menu).
  2. Install to internal storage (eMMC). Erase disk is OK for field wipe.
  3. UEFI, Secure Boot off preferred. Create any temporary admin user.
  4. Reboot into the installed system (remove this stick if it reboots to live).

THEN INSTALL THE APPLIANCE (second stick or network)
  Preferred offline path — plug the FAT32 stick labeled SLS-MEDIA:

    cd /media/$USER/SLS-MEDIA
    # or: cd /run/media/$USER/SLS-MEDIA
    bash install-from-usb.sh
    sudo reboot

  Lab login after appliance:  sls  /  20260717  (change on production)

  Full steps: NEXT-STEPS.txt on this stick, or firmware docs:
    https://github.com/tmdrake/sls-camera-firmware/blob/main/docs/ISO-AND-FIELD-USB.md

FLEET DISPLAY POLICY
  tablet-01 / tablet-02: firmware locks LANDSCAPE (native glass is often portrait).
  Settings app is two-pane landscape (app pin 6fed4e7+).

KINTECT
  External power brick + USB data to the tablet. Not bus-powered.
