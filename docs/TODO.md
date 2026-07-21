# Firmware TODO

**Dependencies / version conflicts:** track on **`sls-camera`** issues  
([#2 offline deps](https://github.com/tmdrake/sls-camera/issues/2),  
[#3 version conflicts](https://github.com/tmdrake/sls-camera/issues/3)) — implement fixes here, close work there.

## Phase 0 — scaffold

- [x] Repo layout, docs, package lists  
- [x] Offline fetch + app sync scripts  
- [x] Overlay stubs (autologin desktop, udev, gspca blacklist, launcher)  
- [x] Link from `sls-camera` docs  

## Phase 1 — appliance install

- [x] Recursive offline debs + apt `--no-download` install path (see sls-camera #2 / #3)  
- [x] Test on clean Lubuntu 26.04 VM (`--demo` smoke + screenshots)  
- [x] SDDM autologin `sls` + Relogin=true  
- [x] `SLS_CAPTURES_DIR` + quit exit-10 contracts (app pin 59ebee6)  
- [x] Landscape lock for fleet tablets (`sls-lock-landscape` + mask iio-sensor-proxy)  
- [x] App pin **6fed4e7** (Settings two-pane landscape; #6 geometry/scroll)  
- [x] Installer-USB root stamp templates (`stamp-installer-usb.sh`)  
- [ ] Test on real tablet  
- [ ] Optional: one-shot kinect-audio-setup doc only (no MS blobs)  

## Phase 2 — blow-and-go media

- [x] Stage A plan: [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md)  
- [x] `50-build-field-usb.sh` — offline firmware tree on SLS-MEDIA stick  
- [x] `prep-sls-media-usb.sh` — wipe stick to FAT32 SLS-MEDIA  
- [ ] Populate field USB and run `install-from-usb.sh` on a wiped tablet  
- [ ] Stage B: choose Cubic / live-build / mkosi  
- [ ] Single appliance ISO in `out/`  
- [ ] Touch-friendly minimal session (strip stock desktop chrome)  

## Phase 3 — harden

- [ ] Read-only root + writable `/data`  
- [ ] Power: inhibit suspend while app running  
- [ ] Factory reset flow  
- [ ] Signed release artifacts / version stamp  

## Backlog

- [ ] ARM64 vendor fetch  
- [ ] OTA update channel (optional)  
