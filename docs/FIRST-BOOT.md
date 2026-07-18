# First boot (appliance)

## Phase 1 (install-appliance.sh)

After install on a blank Ubuntu/Lubuntu system:

1. Reboot  
2. Auto-login as user **`sls`** (if LightDM/GDM config applied)  
3. Autostart launches **`/usr/local/bin/sls-camera`**  
4. SLS app opens fullscreen  

Operator should only need:

- Kinect **power brick** + USB  
- (Optional) audio: `kinect-audio-setup` once if spectrum/record mic required  

## Captures

- Preferred: `/data/sls-captures`  
- Launcher exports `SLS_CAPTURES_DIR` when that directory exists  

## Failure modes

| Symptom | Check |
|---------|--------|
| Black screen / no app | `journalctl -b`, autostart desktop file, `DISPLAY` |
| freenect BUSY | `lsmod \| grep gspca`; blacklist applied? |
| Spectrum silent | `libportaudio2`, Kinect USB Audio after firmware |

## Factory reset (Phase 3)

Re-run `install-appliance.sh` or reflash ISO; wipe `/data` only if operator confirms investigation media can be discarded.
