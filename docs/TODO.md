# Firmware TODO

## Phase 0 — scaffold

- [x] Repo layout, docs, package lists  
- [x] Offline fetch + app sync scripts  
- [x] Overlay stubs (autologin desktop, udev, gspca blacklist, launcher)  
- [x] Link from `sls-camera` docs  

## Phase 1 — appliance install

- [ ] Complete `install-appliance.sh` (users, debs, venv, autologin for LightDM **and** GDM)  
- [ ] Wire captures path into app (`SLS_CAPTURES_DIR` in `sls-camera` if not present)  
- [ ] Test on clean Lubuntu VM + real tablet  
- [ ] Optional: one-shot kinect-audio-setup doc only (no MS blobs)  

## Phase 2 — ISO

- [ ] Choose toolchain: live-build / Cubic / mkosi  
- [ ] Build bootable ISO with offline packages  
- [ ] Calamares/Ubiquity “appliance” install profile  
- [ ] Touch-friendly minimal session (strip stock desktop chrome)  

## Phase 3 — harden

- [ ] Read-only root + writable `/data`  
- [ ] Power: inhibit suspend while app running  
- [ ] Factory reset flow  
- [ ] Signed release artifacts / version stamp  

## Backlog

- [ ] ARM64 vendor fetch  
- [ ] OTA update channel (optional)  
