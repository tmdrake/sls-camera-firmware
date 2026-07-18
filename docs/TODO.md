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
- [ ] Complete autologin for **SDDM** (Lubuntu 26.04) in addition to LightDM/GDM  
- [ ] Wire captures path into app (`SLS_CAPTURES_DIR` in `sls-camera` if not present) — track in app repo  
- [ ] Test on real tablet  
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
